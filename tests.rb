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
    created = @ward.set($dph)
    assert(created)
  end

  def test_set_fail
    assert_raise(ArgumentError) {
      @ward.set({})
    }
  end

  def test_set_get
    @ward.set($dph)
    find = @ward.find('foo.com')
    assert_equal('bar', find['foo.com'])
  end

  def test_set_update
    created = @ward.set($dph)
    assert(created)
    created = @ward.set($dph)
    assert(!created)
  end

  def test_find_fail
    find = @ward.find($dh)
    assert_empty(find)
  end

  def test_set_delete
    created = @ward.set($dph)
    assert(created)
    deleted = @ward.delete($dh)
    assert(deleted)
  end

  def test_delete_fail
    deleted = @ward.delete($dh)
    assert(!deleted)
  end

  def test_set_delete_find_fail
    created = @ward.set($dph)
    assert(created)
    find = @ward.find('foo.com')
    assert_equal('bar', find['foo.com'])
    deleted = @ward.delete($dh)
    assert(deleted)
    find = @ward.find('foo.com')
    assert_empty(find)
  end

  def test_many_set_find
    created = @ward.set($dph)
    assert(created)
    created = @ward.set($DPh)
    assert(created)
    find = @ward.find('foo.com')
    assert_equal('bar', find['foo.com'])
    find = @ward.find('baz.com')
    assert_equal('quux', find['baz.com'])
  end

  def test_find_pattern
    created = @ward.set({ :id => 'foo@bar.com', :password => 'foo' })
    assert(created)
    created = @ward.set({ :id => 'baz@bar.com', :password => 'baz' })
    assert(created)
    matches = @ward.find('bar.com')
    assert_equal('foo', matches['foo@bar.com'])
    assert_equal('baz', matches['baz@bar.com'])
  end

  $d = 'foo.com'
  $p = 'bar'
  $n = 'quux'
  $dh = { :id => $d }
  $ph = { :password => $p }
  $dph = $dh.merge($ph)

  $D = 'baz.com'
  $Dh = { :id => $D }
  $P = 'quux'
  $Ph = { :password => $P }
  $DPh = $Dh.merge($Ph)
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