# frozen_string_literal: true

module ActiveRecordHostPool
  # ActiveRecord 6.0 introduces multiple database support. This introduces a
  # change where dirtying operations on a Mysql2Adapter instance calls out to
  # ActiveRecord::Base.clear_query_caches_for_current_thread. This will
  # for any active connections whose query caches need to be cleared. This
  # involves iterating over every connection handler's connection pool
  # looking for active active connections.
  #
  # This exposes an issue with active active_record_host_pool since by
  # referencing a connection it causes the underlying Mysql2Adapter instance
  # to potentially change its _host_pool_current_database. This means
  # mid-way into carrying out an operation like inserting a record the
  # act of clearing the query cache may select a new database and leave it
  # changed. This can result in the insert SQL then being sent to a new
  # database.
  #
  # This module wraps ActiveRecord::Base.clear_query_caches_for_current_thread
  # in order to restore the current connection's database to what it was
  # before the caches were attempted to be cleared.
  #
  # Before ActiveRecord 6 this potential issue existed in the
  # active_record_host_pool library but no code paths exercised it. This
  # module does not resolve the general issue and the underlying issue still
  # exists, but currently clearing the cache is the only known code path that
  # exercises this problem so that is all that is patched.
  module ResetActiveDatabaseAfterClearingCache
    def clear_query_caches_for_current_thread
      host_pool_current_database_was = connection.unproxied._host_pool_current_database
      super
    ensure
      # restore in case clearing the cache changed the database
      connection.unproxied._host_pool_current_database = host_pool_current_database_was
    end
  end
end

ActiveRecord::Base.singleton_class.prepend ActiveRecordHostPool::ResetActiveDatabaseAfterClearingCache
