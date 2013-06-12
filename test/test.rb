# -*- coding: utf-8 -*-

$: << File.dirname(__FILE__)
require 'test_helper'
require 'test/unit'
require "find"

require 'sffftp'

class TestSffftp < Test::Unit::TestCase

  SFFFTP_WORKING_DIR    = '/tmp/test/sffftp/'
  QUEUE_FOLDER         = "#{SFFFTP_WORKING_DIR}from/"
  OK_FOLDER            = "#{SFFFTP_WORKING_DIR}done/"
  NG_FOLDER            = "#{SFFFTP_WORKING_DIR}error/"
  REMOTE_PATH          = "#{SFFFTP_WORKING_DIR}remote/"
  REMOTE_PORT          = 22
  LOCK_FILE            = "#{SFFFTP_WORKING_DIR}test.lock"
  REMOTE_USER_NAME     = 'paco'
  REMOTE_USER_PASSWORD = nil
  REMOTE_HOST          = "localhost"

  def setup
    FileUtils.mkdir_p(QUEUE_FOLDER)
    FileUtils.mkdir_p(OK_FOLDER)
    FileUtils.mkdir_p(REMOTE_PATH)
    FileUtils.mkdir_p(NG_FOLDER)
    delete_files(QUEUE_FOLDER)
    delete_files(OK_FOLDER)
    delete_files(NG_FOLDER)
    delete_files(REMOTE_PATH)
    files = [
      @l_file     = QUEUE_FOLDER + 'testfile',
      @l_file1    = QUEUE_FOLDER + 'testfile1',
      @l_file2    = QUEUE_FOLDER + 'testfile2',
      @l_file_tmp = QUEUE_FOLDER + 'test.tmp',
      @l_file_ok  = QUEUE_FOLDER + 'test.ok'
    ]
    files.each do |file|
      File.write(file,'test_data')
    end

    @r_file = REMOTE_PATH + "testfile"
    @ng_file = NG_FOLDER + "testfile"
  end

  def delete_files(dir)
    raise 'safety net orz' unless dir =~ %r|/sffftp/|
    Dir::entries(dir).each do |file|
      file = "#{dir}/#{file}"
      next unless File::ftype(file) == 'file'
      File.delete(file) if File.exist?(file)
    end
  end

  def attr
    {
      :logger               => Logger.new('/dev/null'),
      :remote_host          => REMOTE_HOST,
      :remote_user_name     => REMOTE_USER_NAME,
      :remote_user_password => REMOTE_USER_PASSWORD,
      :remote_path          => REMOTE_PATH,
      :queue_folder         => QUEUE_FOLDER,
      :ok_folder            => OK_FOLDER,
      :ng_folder            => NG_FOLDER
    }
  end

  def test_error
    sffftp = Sffftp::Sftp.new(attr)
    sffftp.remote_path = '/tmp/slefijseflislfjsliefjsief/'
    sffftp.timeout = 3
    #sffftp.logger2ssh = true
    sffftp.proceed

    assert_false File.exists?(NG_FOLDER + "testfile2")
  end

  # アップロードに5秒程度かかるように調整が必要
  # スレッド立ててからsleep 1 (ロックファイルが出来る前に
  # 後のプロセスが起動しないように)が良い感じで動くように
  # 個々の値は将来調整しないといけないかもしれない
  def prepare_heavy_test
    (1..500).each do |i|
      file = QUEUE_FOLDER + "#{i}.dat"
      File.write(file,'test_data')
    end
  end

  def test_heavy
    prepare_heavy_test
    sffftp = Sffftp::Sftp.new(attr)
    sffftp.proceed
    # フォルダ含める
    assert_equal (500 + 3 + 1), Find.find(OK_FOLDER).to_a.size
  end

  def test_connection_error
    sffftp = Sffftp::Sftp.new(attr)
    sffftp.remote_host = 'sefisfejisfe.sefijsefij.esfij'
    sffftp.timeout = 3
    #sffftp.logger2ssh = true
    sffftp.proceed

    # コネクションエラーだとキューフォルダーをいじらない
    assert_true File.exists?(QUEUE_FOLDER + "testfile2")
  end

  # メソッドの機能チェック
  def test_file_size_check
    sffftp = Sffftp::Sftp.new(attr)
    sffftp.connect
    assert_false sffftp.__send__ :file_size_check, @l_file,@r_file
    assert_false File.exists?(@r_file)
  end

  # upload_data_fileをエミュレートして問題が出るか？のチェック
  def test_upload_data_file_error
    sffftp = Sffftp::Sftp.new(attr)
    sffftp.connect
    sffftp.__send__ :upload_inner,@l_file,@r_file
    change_file_size(@r_file)
    unless sffftp.__send__ :file_size_check,@l_file,@r_file
      sffftp.__send__ :remove_uploaded_file, @r_file
    end
    assert_false File.exists?(@r_file)
  end

  def change_file_size(file)
    f = File::open(file, "a")
    f.write('plus line')
    f.close
  end

  # リモートにファイルがすでにある
  # が、okファイルはまだない！
  # って時
  def test_erace_existed_file_case_1

    File.write(@r_file,'test_data')

    sffftp = Sffftp::Sftp.new(attr)
    sffftp.connect

    assert_true sffftp.__send__ :erace_existed_file, @r_file
    assert_false File.exists?(@r_file)
  end

  # リモートにファイルがすでにある
  # okファイルもあるよ、、、
  # って時
  def test_erace_existed_file_case_2

    File.write(@r_file,'test_data')
    File.write(@r_file + ".ok",'test_data')

    sffftp = Sffftp::Sftp.new(attr)
    sffftp.connect

    assert_raise do
      assert_true sffftp.__send__ :erace_existed_file, @r_file
    end
  end

  # リモートにファイルが既にあるよ
  def test_proceed_remote_file_exists_case_1
    File.write(@r_file,'test_data')
    sffftp = Sffftp::Sftp.new(attr)
    sffftp.proceed

    assert_false File.exists?(@ng_file)
  end

  # リモートにファイルが既にあるよ
  # okファイルまであるよ！！！
  def test_proceed_remote_file_exists_case_2
    File.write(@r_file,'test_data')
    File.write(@r_file + ".ok",'test_data')
    sffftp = Sffftp::Sftp.new(attr)
    sffftp.proceed

    # okファイルまである場合はNGフォルダに
    # データを移動する
    assert_true File.exists?(@ng_file)
  end

  def set_attr_to_instance!(sffftp)
    sffftp.logger               = Logger.new('/dev/null')
    sffftp.remote_host          = REMOTE_HOST
    sffftp.remote_user_name     = REMOTE_USER_NAME
    sffftp.remote_user_password = REMOTE_USER_PASSWORD
    sffftp.remote_path          = REMOTE_PATH
    sffftp.ok_folder            = OK_FOLDER
    sffftp.ng_folder            = NG_FOLDER
    sffftp.queue_folder         = QUEUE_FOLDER
  end

  def test_sffftp
    assert_true File.exists?(@l_file)
    assert_true File.exists?(@l_file1)

    sffftp = Sffftp::Sftp.new()
    assert_raise do
      sffftp.proceed
    end
    set_attr_to_instance!(sffftp)

    # 取り敢えず無いフォルダ名で設定してみる
    sffftp.queue_folder = 'hohogege'
    assert_raise do
      sffftp.proceed
    end
    sffftp.queue_folder = QUEUE_FOLDER

    sffftp.proceed
    assert_true File.exists?(REMOTE_PATH + "testfile2")
    assert_true File.exists?(REMOTE_PATH + "testfile2.ok")

    assert_true File.exists?(@l_file_tmp)
    assert_true File.exists?(@l_file_ok)
  end

  def test_socket_error
    assert_true File.exists?(@l_file)
    sffftp = Sffftp::Sftp.new()
    set_attr_to_instance!(sffftp)
    sffftp.remote_host = '255.255.255.255'
    sffftp.proceed
    assert_true File.exists?(@l_file)
  end

  def test_sffftp_with_port
    assert_true File.exists?(@l_file)
    assert_true File.exists?(@l_file1)
    sffftp = Sffftp::Sftp.new()
    set_attr_to_instance!(sffftp)
    # ここが増えただけ
    sffftp.remote_port = REMOTE_PORT
    sffftp.proceed

    assert_true File.exists?(REMOTE_PATH + "testfile2")
    assert_true File.exists?(REMOTE_PATH + "testfile2.ok")

    assert_true File.exists?(@l_file_tmp)
    assert_true File.exists?(@l_file_ok)
  end

end
