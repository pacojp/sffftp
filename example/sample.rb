require 'sffftp'

REMOTE_HOST = 'localhost'
REMOTE_USER_NAME = 'paco'
REMOTE_USER_PASSWORD = nil
WORK_SPACE = '/tmp/test/sffftp_sample/'
REMOTE_PATH = WORK_SPACE + 'remote/'
QUEUE_FOLDER = WORK_SPACE + 'from/'
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

sffftp = sffftp::Scp.new
sffftp.remote_host          = REMOTE_HOST
sffftp.remote_user_name     = REMOTE_USER_NAME
sffftp.remote_user_password = REMOTE_USER_PASSWORD
sffftp.remote_path          = REMOTE_PATH
sffftp.queue_folder         = QUEUE_FOLDER
sffftp.ok_folder            = OK_FOLDER
sffftp.ng_folder            = NG_FOLDER
sffftp.proceed
