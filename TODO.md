Features that sooner or later will be added to `ngx_postgres`:

* Make sure that we work-around `bytea` data corruption that takes place
  when using 9.0+ database with older client library or vice-versa.

* Add support for SSL connections to the database.

* Add support for dropping of idle keep-alived connections to the
  database.

* Add support for sending mulitple queries in one go (transactions,
  multiple SELECTs, etc), this will require changes in the processing
  flow __and__ RDS format.

* Add `postgres_escape_bytea` or `postgres_escape_binary`.

* Use `PQescapeStringConn()` instead of `PQescapeString()`, this will
  require lazy-evaluation of the variables after we acquire connection,
  but before we send query to the database.  
  Notes: Don't break `$postgres_query`.

* Cancel long-running queries using `PQcancel()`.

* Detect client library version using `PQlibVersion()` (PostgreSQL 9.1+)
  or exports (for older releases):

      8.0.0 -> PQcancel                  122
      8.1.0 -> PQregisterThreadLock      125
      8.1.4 -> PQescapeByteaConn         127
      8.2.0 -> PQsendDescribePortal      136
      8.3.0 -> PQconnectionNeedsPassword 140
      8.4.0 -> PQinitOpenSSL             153
      8.5.x -> PQinitOpenSSL             153
      9.0.0 -> PQconnectStartParams      157
      9.1.x -> PQlibVersion              160

* Detect server version using `PQserverVersion()`.
