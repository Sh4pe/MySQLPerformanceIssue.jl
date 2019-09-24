# Some performance issues with MySQL.jl

Developed for [this issue](...)


## Scripts

Basic perfomance measurement.

```julia
include("MySQLPerf.jl"); MySQLPerf.with_conn() do conn
    @time MySQLPerf.populate_test_table(conn, "test_table", num_rows=10000)
    for i in 2:29
        @time MySQLPerf.wide_query(conn, "test_table", i)
    end
end
```