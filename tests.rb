require 'ward'
require 'command'
require 'test/unit'
require 'tempfile'
require 'yaml'

class TestWard < Test::Unit::TestCase
  def setup
    @temp_store = Tempfile.new('ward')
    @master_password = 'test'
    @ward = Ward.new(@temp_store.path, @master_password, 10)
  end

  def teardown
    @temp_store.delete rescue nil
  end

  def test_set
    created = @ward.set('foo.com', 'bar')
    assert(created)
  end

  def test_set_no_id_fail
    assert_raise(ArgumentError) {
      @ward.set(nil, 'bar')
    }
  end

  def test_set_no_password_fail
    assert_raise(ArgumentError) {
      @ward.set('foo.com', nil)
    }
  end

  def test_set_find
    @ward.set('foo.com', 'bar')
    find = @ward.find('foo.com')
    assert_equal('bar', find['foo.com'])
  end

  def test_set_update
    created = @ward.set('foo.com', 'bar')
    assert(created)
    created = @ward.set('foo.com', 'bar')
    assert(!created)
  end

  def test_find_fail
    find = @ward.find('foo.com')
    assert_empty(find)
  end

  def test_set_find_fail
    created = @ward.set('foo.com', 'bar')
    assert(created)
    find = @ward.find('bar.com')
    assert_empty(find)
  end

  def test_set_delete
    created = @ward.set('foo.com', 'bar')
    assert(created)
    deleted = @ward.delete('foo.com')
    assert(deleted)
  end

  def test_delete_fail
    deleted = @ward.delete('foo.com')
    assert(!deleted)
  end

  def test_set_delete_find_fail
    created = @ward.set('foo.com', 'bar')
    assert(created)
    find = @ward.find('foo.com')
    assert_equal('bar', find['foo.com'])
    deleted = @ward.delete('foo.com')
    assert(deleted)
    find = @ward.find('foo.com')
    assert_empty(find)
  end

  def test_many_set_find
    created = @ward.set('foo.com', 'bar')
    assert(created)
    created = @ward.set('baz.com', 'quux')
    assert(created)
    find = @ward.find('foo.com')
    assert_equal('bar', find['foo.com'])
    find = @ward.find('baz.com')
    assert_equal('quux', find['baz.com'])
  end

  def test_find_pattern
    created = @ward.set('foo@bar.com', 'foo')
    assert(created)
    created = @ward.set('baz@bar.com', 'baz')
    assert(created)
    matches = @ward.find('bar.com')
    assert_equal('foo', matches['foo@bar.com'])
    assert_equal('baz', matches['baz@bar.com'])
  end

  def test_list_empty
    count = 0
    @ward.each_password {
      count += 1
    }

    assert_equal(0, count)
  end

  def test_set_list
    created = @ward.set('foo@bar.com', 'foo')
    assert(created)
    @ward.each_password { |id, password|
      assert_equal('foo@bar.com', id)
      assert_equal('foo', password)
    }
  end
end

class TestCommand < Test::Unit::TestCase
  def setup
    @temp_store = Tempfile.new('command')
    @master_password = 'test'
  end

  def teardown
    @temp_store.delete rescue nil
  end

  def cmd(*args)
    WardCommand.run(@temp_store.path, args)
  end

  def test_set
  end

  def test_set_alias
  end

  def test_get_alias
  end

  def test_delete_alias
  end
end