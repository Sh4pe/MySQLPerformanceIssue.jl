module MySQLPerf

import MySQL
using DataFrames

module Docker

    const ContainerName = "mysqlperf_container"
    const ImageName = "mysqlperf_image"
    const HostPort = 3306
    const Addr = "127.0.0.1"
    const RootPassword = "this_is_not_safe"
    const DBName = "perf_test"

    function build()
        println("building container $ImageName")
        run(`docker build . -t $ImageName`)
    end

    "Returns the id of the running container"
    function start()
        print("Starting $ContainerName... ")
        cmd = `docker run --rm 
            -p $HostPort:3306 
            --name $ContainerName
            -e MYSQL_ROOT_PASSWORD=$RootPassword
            -e MYSQL_DATABASE=$DBName
            -d $ImageName`
        id = open(process -> readline(process.out), cmd, "r")
        println("done. ID: $id")
        id
    end

    function stop(id)
        println("Stopping container $id")
        run(`docker stop $id`)
    end

    function wait_until_mysql_ready(id)
        print("Waiting for MySQL to become ready")
        cmd = `docker exec $id mysql -uroot -p$RootPassword -e 'show databases'` 
        exitcode = 1
        while exitcode != 0
            print(".")
            sleep(1)
            process = run(cmd, wait=false)
            wait(process)
            exitcode = process.exitcode
        end
        println(" ready.")
    end

    function with_container(func)
        build()
        local id
        try
            id = start()
            wait_until_mysql_ready(id)
            func(id, Addr, HostPort, RootPassword, DBName)
        finally
            stop(id)
        end
    end
end # module Docker

"run code in the context of a connection to a Docker based MySQL database"
function with_conn(func)
    local conn
    try
        Docker.with_container() do id, addr, port, pwd, db_name
            print("Establishing MySQL connection... ")
            conn = MySQL.connect(addr, "root", pwd, db=db_name, port=port)
            println("done.")
            func(id, conn)
        end
    finally
        print("Closing MySQL connection... ")
        MySQL.disconnect(conn)
        println("done.")
    end
end

function populate_test_table(conn, table_name::String; float_fields=15, string_fields=15, num_rows=1000)
    @assert string_fields > 1
    @assert float_fields > 1

    drop_stmt = "DROP TABLE IF EXISTS $table_name;"
    float_cols = ["f$i" for i in 1:float_fields]
    string_cols = ["s$i" for i in 1:string_fields]
    create_stmt = """
        CREATE TABLE $table_name (
            $(join(["$x FLOAT" for x in float_cols], ",")),
            $(join(["$x TEXT" for x in string_cols], ","))
        );
    """

    str_lookup = Dict(zip(0:9, ["a","b","c","d","e","f","g","h","i","j"]))

    MySQL.execute!(conn, drop_stmt)
    MySQL.execute!(conn, create_stmt)

    insert_stmt_str = """
        INSERT INTO $table_name ($(join(float_cols,", ")),$(join(string_cols,", "))) 
        VALUES ($(join(repeat(["?"],float_fields + string_fields),", ")));
    """
    insert_stmt = MySQL.Stmt(conn, insert_stmt_str)

    for i in 1:num_rows
        random_floats = rand(float_fields)
        random_strings = ["\"$(str_lookup[i])\"" for i in (Int ∘ floor).(rand(string_fields) * 10)]
        MySQL.execute!(insert_stmt, vcat(random_floats, random_strings))
    end
end

"Creates a DataFrame (not used) and return its shape"
function wide_query(conn, table_name::String, num_fields::Integer; float_fields=15, string_fields=15, limit=100)
    @assert float_fields > 1
    @assert string_fields > 1
    @assert num_fields > 1

    fields = vcat(["f$i" for i in 1:float_fields], ["s$i" for i in 1:string_fields])[1:num_fields]
    query = "SELECT $(join(fields, ", ")) FROM $table_name LIMIT $limit;"
    df = MySQL.Query(conn, query) |> DataFrame
    size(df)
end

end # modlue MySQLPerf