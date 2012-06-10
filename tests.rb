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
    get = @ward.get($dh)
    assert_equal($p, get)
  end

  def test_set_update
    created = @ward.set($dph)
    assert(created)
    created = @ward.set($dph)
    assert(!created)
  end

  def test_get_fail
    get = @ward.get($dh)
    assert_nil(get)
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

  def test_set_delete_get_fail
    created = @ward.set($dph)
    assert(created)
    get = @ward.get($dh)
    assert_equal($p, get)
    deleted = @ward.delete($dh)
    assert(deleted)
    get = @ward.get($dh)
    assert_nil(get)
  end

  def test_many_set_get
    created = @ward.set($dph)
    assert(created)
    created = @ward.set($DPh)
    assert(created)
    get = @ward.get($dh)
    assert_equal($p, get)
    get = @ward.get($Dh)
    assert_equal($P, get)
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