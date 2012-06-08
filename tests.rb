require 'ward'
require 'command'
require 'test/unit'
require 'tempfile'

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
    assert_raise(WardError) {
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

  def test_set_nick
    created = @ward.set($dpnh)
    assert(created)
  end

  def test_get_nick
    created = @ward.set($dpnh)
    assert(created)
    get = @ward.get($nh)
    assert_equal($p, get)
  end

  def test_get_nick_fail
    get = @ward.get($nh)
    assert_nil(get)
  end

  def test_delete_nick
    created = @ward.set($dpnh)
    assert(created)
    deleted = @ward.delete($nh)
    assert(deleted)
  end

  def test_delete_nick_fail
    deleted = @ward.delete($nh)
    assert(!deleted)
  end

  def test_nick_update
    created = @ward.set($dpnh)
    assert(created)
    created = @ward.set($Pnh)
    assert(!created)
    get = @ward.get($nh)
    assert_equal($P, get)
  end

  def test_set_nick_fail
    assert_raise(WardError) {
      @ward.set($pnh)
    }
  end

  def test_nick_unique
    created = @ward.set($dpnh)
    assert(created)
    assert_raise(WardError) {
      @ward.set($Dpnh)
    }
  end

  def test_set_delete_set_nick
    created = @ward.set($dpnh)
    assert(created)
    deleted = @ward.delete($nh)
    assert(deleted)
    created = @ward.set($Dpnh)
    assert(created)
  end

  $d = 'foo.com'
  $p = 'bar'
  $n = 'quux'
  $dh = { :domain => $d }
  $ph = { :password => $p }
  $nh = { :nick => $n }
  $dph = $dh.merge($ph)
  $dpnh = $dph.merge($nh)
  $pnh = $ph.merge($nh)

  $D = 'baz.com'
  $Dh = { :domain => $D }
  $P = 'quux'
  $Ph = { :password => $P }
  $DPh = $Dh.merge($Ph)
  $N = 'waldo'
  $Nh = { :nick => $N }
  $DPNh = $DPh.merge($Nh)

  $Pnh = $Ph.merge($nh)
  $Dpnh = $Dh.merge($pnh)
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