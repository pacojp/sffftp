# -*- coding: utf-8 -*-

require 'sffftp'

require 'batchbase'
include Batchbase::Core
# https://github.com/pacojp/batchbase
#
# 2重起動防止
# シグナル管理
# デーモン化
#

#create_logger('/tmp/batchbase_test_sample1.log')
create_logger(STDOUT)
def receive_signal(signal)
  logger.info("receive signal #{signal}")
  @stop = true
end
set_signal_observer(:receive_signal,self)
@stop = false

REMOTE_HOST = 'localhost'
REMOTE_USER_NAME = 'paco'
REMOTE_USER_PASSWORD = nil
WORK_SPACE = '/tmp/test/sffftp_sample/'
REMOTE_PATH = WORK_SPACE + 'remote/'
QUEUE_FOLDER = WORK_SPACE + 'from/'
#
# sffftp内で実装している二重起動防止機能
# (QUEUE_FOLDER内に.pidファイルがある場合
# その値と$$を比較し、違う場合はraiseする)を
# 有効にするにはlockファイルを
# "#{QUEUE_FOLDER}.pid"に設定する
#
# このスクリプトで同内容を確認するには
# 本スクリプトで起動した後以下のLOCKFILEの
# 項目のコメントアウトを入れ替えて再実行すると
# sffftp内のraiseが確認できる
#
LOCKFILE = QUEUE_FOLDER + '.pid'
#LOCKFILE = WORK_SPACE + '.sffftp.lock'

OK_FOLDER = WORK_SPACE + 'ok'
NG_FOLDER = WORK_SPACE + 'ng'

<<`MKDIR`
mkdir -p /tmp/test/sffftp_sample/from
mkdir -p /tmp/test/sffftp_sample/ok
mkdir -p /tmp/test/sffftp_sample/ng
mkdir -p /tmp/test/sffftp_sample/remote
touch /tmp/test/sffftp_sample/from/file1
touch /tmp/test/sffftp_sample/from/file2.tmp
touch /tmp/test/sffftp_sample/from/file3.ok
MKDIR

execute(:pid_file=>LOCKFILE) do
  sffftp = Sffftp::Sftp.new()
  sffftp.logger               = logger
  sffftp.remote_host          = REMOTE_HOST
  sffftp.remote_user_name     = REMOTE_USER_NAME
  sffftp.remote_user_password = REMOTE_USER_PASSWORD
  sffftp.remote_path          = REMOTE_PATH
  sffftp.queue_folder         = QUEUE_FOLDER
  sffftp.ok_folder            = OK_FOLDER
  sffftp.ng_folder            = NG_FOLDER
  set_signal_observer(:receive_signal,sffftp)

  loop do
    cnt = sffftp.proceed
    logger.info "#{cnt} files uploaded"
    break_loop = false
    5.times do
      sleep 1
      if @stop
        break_loop = true
        break
      end
    end
    break if break_loop
  end
end
