require 'net/sftp'
require 'fileutils'

module Sffftp
  class Sftp
    ATTRS = [
      :remote_host,
      :remote_user_name,
      :remote_user_password,
      :remote_path,
      :remote_port,
      :queue_folder,
      :ok_folder,
      :ng_folder,
      :timeout,
      :logger2ssh,
      :logger
    ]
    ATTRS.each do |_attr|
      attr_accessor _attr
    end

    attr_accessor :connection

    def initialize(opts={})
      self.remote_port = 22
      self.logger      = Logger.new(STDOUT)
      opts.each do |k, v|
        send("#{k}=", v)
      end
    end

    def attrs_ok?
      ATTRS.each do |attr|
        #v = instance_variable_get("@#{attr.to_s}")
        v = send(attr)
        case attr
        when :remote_user_name,:remote_user_password,:timeout,:logger2ssh
          next
        when :queue_folder,:ok_folder,:ng_folder
          unless File.directory?(v)
            raise "#{attr}:#{v} is not folder"
          end
        else
          unless v
            raise %|must set "#{attr}" at least|
          end
        end
      end
      true
    end

    def receive_signal(signal)
      @killing = true
    end

    def connect(close_connected_instance=true)
      if close_connected_instance
        close if connection && connection.open?
      end
      if connection && connection.open?
        unless close_connected_instance
          return self.connection
        end
      end

      opt = {}
      opt[:port] = remote_port
      if remote_user_password
        opt[:password] = remote_user_password
      end
      if timeout
        opt[:timeout] = timeout
      end
      if logger2ssh
        opt[:logger] = logger
      end
      self.connection = Net::SFTP.start(remote_host, remote_user_name, opt)
    end

    def close
      begin
        if connection && connection.open?
          connection.close
        end
      rescue
      end
    end

    def proceed
      attrs_ok?

      files = Dir::entries(queue_folder).map{|o|"#{queue_folder}/#{o}"}
      files = files.select do |o|
        File::ftype(o) == "file" &&
          !(o =~ /\.(tmp|ok)$/)
      end

      unless @__not_first_time_to_proceed
        logger.info("queue_folder: #{queue_folder}")
        logger.info("target: #{remote_user_name}@#{remote_host}:#{remote_port}:#{remote_path}")
        @__not_first_time_to_proceed = true
      end
      uploaded_count = 0

      begin
        connect
        files.each do |file|
          break if @killing
          if upload!(file)
            uploaded_count += 1
          end
        end
      # ハンドルできないエラーは取り敢えず現状維持をモットーとする
      rescue => e
        logger.error e.message
        logger.error e.backtrace.join("\n")
      ensure
        close
      end

      uploaded_count
    end

    private

    def upload!(file)
      to_path = remote_path + '' + File.basename(file)
      begin
        logger.info "upload process start: #{file}"
        # 既に同名ファイルがリモートに有る場合、対処できるならする
        # 出来ないなら(okファイルもすでにある等)raiseする
        erace_existed_file(to_path)
        # リモートにファイルをアップする
        return false unless upload_data_file(file,to_path)
        # okファイルをリモートに作成する
        return false unless create_ok_file(to_path)
        # 処理終了フォルダにデータを移動する
        FileUtils.mv(file,ok_folder)
        logger.info "upload process finish: #{file}"
        return true
      rescue SocketError => socket_error
        # 通信エラーの場合は取り敢えず現状を維持して
        # 次の処理に移る
        logger.warn socket_error
        connect(true)
      rescue => e
        # 処理失敗フォルダに移動する
        logger.error e
        FileUtils.mv(file,ng_folder)
        logger.error "upload process error: #{file}"
      end
      false
    end

    # アップロード先に既に同一ファイルが有る場合は
    # 取り敢えず消してから作業を開始する
    # が、okファイルがある場合エクセプションを投げて
    # 諦める
    def erace_existed_file(to)
      oh_my_god = false
      ok_file = to + ".ok"
      begin
        connection.stat!(to)
        begin
          connection.stat!(ok_file)
          # ナンテコッタイ okファイルが有るよ、、、
          logger.error "ok_file already exists remote: #{ok_file}"
          oh_my_god = true
        rescue
          # okファイルが無いからファイルを消す
          logger.warn "file already exists. so erace it: #{ok_file}"
          connection.remove(to).wait
        end
      rescue
        # エラーでOK = ファイルが無い
      end
      if oh_my_god
        raise 'file and ok_file already exists on remote server!!!'
      end
      true
    end

    def upload_data_file(from,to)
      upload_inner(from,to) rescue nil
      unless file_size_check(from,to)
        logger.info "upload error: #{from} => #{to}"
        remove_uploaded_file(to)
        return false
      end
      logger.info "uploaded: #{from} => #{to}"
      true
    end

    def create_ok_file(to)
      to_path = to  + ".ok"
      logger.info "create ok_file: #{to_path}"
      connection.file.open(to_path,"w") do |file|
        #file.write('')
      end

      # okファイルのあげミスは、OKファイルを消してエラーを上げてそれ以上は
      # なにもしない
      unless file_size_check(0,to_path)
        logger.error "create ok_file error: #{to_path}"
        return false
      end
      logger.info "created: #{to_path}"
      true
    end

    def remove_uploaded_file(to)
      logger.warn "removing: #{to}"
      begin
        connection.remove(to).wait
      rescue => e
        logger.error e.message
        logger.error e.backtrace.join("\n")
      end
    end

    def file_size_check(from,to)
      if from.kind_of?(Numeric)
        ori_file_size = from
      else
        ori_file_size = File::Stat.new(from).size
      end
      remote_file_size = -1
      begin
        connection.file.open(to) do |file|
          remote_file_size = file.stat.size
        end
        if ori_file_size == remote_file_size
          logger.info "file size ok: #{ori_file_size}/#{remote_file_size}"
          return true
        end
        logger.warn "file size ng: #{ori_file_size}/#{remote_file_size}"
      rescue => e
        logger.warn e.message
        logger.warn e.backtrace.join("\n")
      end
      false
    end

    def upload_inner(from,to)
      logger.info "upload: #{from} => #{to}"
      connection.upload! from, to
    end
  end
end
