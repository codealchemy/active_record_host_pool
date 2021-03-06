# frozen_string_literal: true

require_relative 'helper'

class ActiveRecordHostPoolTest < Minitest::Test
  include ARHPTestSetup
  def setup
    Phenix.rise!
    arhp_create_models
  end

  def teardown
    Phenix.burn!
  end

  def test_process_forking_with_connections
    # Ensure we have a connection already
    assert_equal(true, ActiveRecord::Base.connected?)

    # Verify that when we fork, the process doesn't crash
    pid = Process.fork do
      if ActiveRecord::VERSION::MAJOR == 5 && ActiveRecord::VERSION::MINOR == 2
        assert_equal(false, ActiveRecord::Base.connected?) # New to Rails 5.2
      else
        assert_equal(true, ActiveRecord::Base.connected?)
      end
    end
    Process.wait(pid)
    # Cleanup any connections we may have left around
    ActiveRecord::Base.connection_handler.clear_all_connections!
  end

  def test_models_with_matching_hosts_should_share_a_connection
    assert_equal(Test1.connection.raw_connection, Test2.connection.raw_connection)
    assert_equal(Test3.connection.raw_connection, Test4.connection.raw_connection)
  end

  def test_models_without_matching_hosts_should_not_share_a_connection
    refute_equal(Test1.connection.raw_connection, Test4.connection.raw_connection)
  end

  def test_models_without_matching_usernames_should_not_share_a_connection
    refute_equal(Test4.connection.raw_connection, Test5.connection.raw_connection)
  end

  def test_models_without_match_slave_status_should_not_share_a_connection
    refute_equal(Test1.connection.raw_connection, Test1Slave.connection.raw_connection)
  end

  def test_should_select_on_correct_database
    assert_action_uses_correct_database(:select_all, 'select 1')
  end

  def test_should_insert_on_correct_database
    assert_action_uses_correct_database(:insert, "insert into tests values(NULL, 'foo')")
  end

  def test_connection_returns_a_proxy
    assert_kind_of ActiveRecordHostPool::ConnectionProxy, Test1.connection
  end

  def test_connection_proxy_handles_private_methods
    # Relies on connection.class returning the real class
    Test1.connection.class.class_eval do
      private

      def test_private_method
        true
      end
    end
    assert Test1.connection.respond_to?(:test_private_method, true)
    refute Test1.connection.respond_to?(:test_private_method)
    assert_includes(Test1.connection.private_methods, :test_private_method)
    assert_equal true, Test1.connection.send(:test_private_method)
  end

  def test_should_not_share_a_query_cache
    Test1.create(val: 'foo')
    Test2.create(val: 'foobar')
    Test1.connection.cache do
      refute_equal Test1.first.val, Test2.first.val
    end
  end

  def test_object_creation
    Test1.create(val: 'foo')
    assert_equal('arhp_test_1', current_database(Test1))

    Test3.create(val: 'bar')
    assert_equal('arhp_test_1', current_database(Test1))
    assert_equal('arhp_test_3', current_database(Test3))

    Test2.create!(val: 'bar_distinct')
    assert_equal('arhp_test_2', current_database(Test2))
    assert Test2.find_by_val('bar_distinct')
    refute Test1.find_by_val('bar_distinct')
  end

  def test_disconnect
    Test1.create(val: 'foo')
    unproxied = Test1.connection.unproxied
    Test1.connection_handler.clear_all_connections!
    Test1.create(val: 'foo')
    assert(unproxied != Test1.connection.unproxied)
  end

  def test_checkout
    connection = ActiveRecord::Base.connection_pool.checkout
    assert_kind_of(ActiveRecordHostPool::ConnectionProxy, connection)
    ActiveRecord::Base.connection_pool.checkin(connection)
    c2 = ActiveRecord::Base.connection_pool.checkout
    assert(c2 == connection)
  end

  def test_no_switch_when_creating_db
    conn = Test1.connection
    conn.expects(:execute_without_switching)
    conn.expects(:_switch_connection).never
    assert conn._host_pool_current_database
    conn.create_database(:some_args)
  end

  def test_no_switch_when_dropping_db
    conn = Test1.connection
    conn.expects(:execute_without_switching)
    conn.expects(:_switch_connection).never
    assert conn._host_pool_current_database
    conn.drop_database(:some_args)
  end

  def test_underlying_assumption_about_test_db
    debug_me = false
    # ensure connection
    Test1.first

    # which is the "default" DB to connect to?
    first_db = Test1.connection.unproxied.instance_variable_get(:@_cached_current_database)
    puts "\nOk, we started on #{first_db}" if debug_me

    switch_to_klass = case first_db
    when 'arhp_test_2'
      Test1
    when 'arhp_test_1'
      Test2
    else
      raise "Expected a database name, got #{first_db.inspect}"
    end
    expected_database = switch_to_klass.connection.instance_variable_get(:@database)

    # switch to the other database
    switch_to_klass.first
    puts "\nAnd now we're on #{current_database(switch_to_klass)}" if debug_me

    # get the current thread id so we can shoot ourselves in the head
    thread_id = switch_to_klass.connection.select_value('select @@pseudo_thread_id')

    # now, disable our auto-switching and trigger a mysql reconnect
    switch_to_klass.connection.unproxied.stubs(:_switch_connection).returns(true)
    Test3.connection.execute("KILL #{thread_id}")

    # and finally, did mysql reconnect correctly?
    puts "\nAnd now we end up on #{current_database(switch_to_klass)}" if debug_me
    assert_equal expected_database, current_database(switch_to_klass)
  end

  def test_release_connection
    pool = ActiveRecord::Base.connection_pool
    conn = pool.connection
    pool.expects(:checkin).with(conn)
    pool.release_connection
  end

  private

  def assert_action_uses_correct_database(action, sql)
    (1..4).each do |i|
      klass = ARHPTestSetup.const_get("Test#{i}")
      desired_db = "arhp_test_#{i}"
      klass.connection.send(action, sql)
      assert_equal desired_db, current_database(klass)
    end
  end
end
