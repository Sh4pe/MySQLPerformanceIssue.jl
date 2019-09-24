# Some performance issues with MySQL.jl

Developed for [this issue](...)


## Scripts

Basic perfomance measurement.

```julia
include("MySQLPerf.jl"); MySQLPerf.with_conn() do id, conn
    @time MySQLPerf.populate_test_table(conn, "test_table", num_rows=10000)
    for i in 2:29
        @time MySQLPerf.wide_query(conn, "test_table", i)
    end
end
```

Make a dump.

```julia
include("MySQLPerf.jl"); MySQLPerf.with_conn() do id, conn
    MySQLPerf.populate_test_table(conn, "test_table", num_rows=1000)
    MySQLPerf.Docker.make_dump(id, "dump.sql")
end
```