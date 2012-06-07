require 'ward'
require 'test/unit'
require 'tempfile'

class TestWard < Test::Unit::TestCase
  def setup
    @temp_store = Tempfile.new('ward')
    @master_password = 'test'
    @ward = Ward.new(@temp_store.path, @master_password)
  end

  def teardown
    @temp_store.delete rescue nil
  end

  def test_set
    created = @ward.set($dph)
    assert(created)
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
    password = @ward.get($dh)
    assert_nil(password)
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
    created = @ward.set($d2p2h)
    assert(created)
    get = @ward.get($dh)
    assert_equal($p, get)
    get = @ward.get($d2h)
    assert_equal($p2, get)
  end

  def test_set_nick
  end

  def test_get_nick
  end

  def test_delete_nick
  end

  def test_nick_unique
  end

  def test_set_alias
  end

  def test_get_alias
  end

  def test_delete_alias
  end

  $d = 'foo.com'
  $p = 'bar'
  $dh = { :domain => $d }
  $ph = { :password => $p }
  $dph = $dh.merge($ph)

  $d2 = 'baz.com'
  $d2h = { :domain => $d2 }
  $p2 = 'quux'
  $p2h = { :password => $p2 }
  $d2p2h = $d2h.merge($p2h)
end

class TestCommand < Test::Unit::TestCase
  def setup
  end

  def teardown
  end

  def test_set
  end
end