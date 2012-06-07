require 'ward'
require 'test/unit'
require 'tempfile'

class TestWard < Test::Unit::TestCase
  def setup
    password = 'test'
    @temp_store = Tempfile.new('ward')
    @ward = Ward.new(@temp_store.path, password)
  end

  def teardown
    @temp_store.delete rescue nil
  end

  def test_set
    created = @ward.set(:domain => 'foo.com', :password => 'bar')
    assert(created)
  end

  def test_set_get
    password = 'bar'
    @ward.set(:domain => 'foo.com', :password => password)
    get = @ward.get(:domain => 'foo.com')
    assert_equal(password, get)
  end

  def test_set_update
    created = @ward.set(:domain => 'foo.com', :password => 'bar')
    assert(created)
    created = @ward.set(:domain => 'foo.com', :password => 'baz')
    assert(!created)
  end

  def test_get_fail
    password = @ward.get(:domain => 'foo.com')
    assert_nil(password)
  end

  def test_set_delete
    created = @ward.set(:domain => 'foo.com', :password => 'bar')
    assert(created)
    deleted = @ward.delete(:domain => 'foo.com')
    assert(deleted)
  end

  def test_delete_fail
    deleted = @ward.delete(:domain => 'foo.com')
    assert(!deleted)
  end

  def test_set_delete_get_fail
    password = 'bar'
    created = @ward.set(:domain => 'foo.com', :password => password)
    assert(created)
    get = @ward.get(:domain => 'foo.com')
    assert_equal(password, get)
    deleted = @ward.delete(:domain => 'foo.com')
    assert(deleted)
    get = @ward.get(:domain => 'foo.com')
    assert_nil(get)
  end

  def test_set_nick
  end
end