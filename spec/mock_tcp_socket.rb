
class MockTCPSocket
  include Fastdfs::Client

  attr_accessor :host, :port, :cmd, :recv_offset, :connect_state

  def initialize(host, port)
    @host = host
    @port = port
    @recv_offset = 0
    @connect_state = true
    @cmd = nil
    @content = []
    @header = []
  end

  def connection
    @content = []
    @header = []
  end

  def write(*args)
    pkg = args[0].unpack("C*")
    if @header.length <= 0
      @header = pkg
    else
      @content.concat(pkg)  
    end
    @cmd ||= pkg[8]
    sleep(rand(0..4))
  end

  def recv(len)
    sleep(rand(0..2))
    data = case @cmd
    when 101
      gate_tracker(len)
    when 11
      upload_file(len)
    when 12
      delete_file(len)
    when 15
      get_metadata(len)
    when 13
      set_metadata(len)
    when 14
      download_file(len)
    end
    @recv_offset = len
    data
  end

  def close
    @recv_offset = 0
    @connect_state = false
    @cmd = nil
  end

  def closed?
    @connect_state
  end

  private 
  def gate_tracker(len)
    header = ProtoCommon.header_bytes(CMD::RESP_CODE, 0)
    header[7] = ProtoCommon::TRACKER_BODY_LEN

    group_name = Utils.array_merge([].fill(0, 0...16), TestConfig::GROUP_NAME.bytes)
    ip = Utils.array_merge([].fill(0, 0...15), TestConfig::STORAGE_IP.bytes)
    port = TestConfig::STORAGE_PORT.to_i.to_eight_buffer
    store_path = Array(TestConfig::STORE_PATH)

    (header+group_name+ip+port+store_path)[@recv_offset...@recv_offset+len].pack("C*")
  end

  def upload_file(len)
    header = ProtoCommon.header_bytes(CMD::RESP_CODE, 0)
    group_name = Utils.array_merge([].fill(0, 0...16), TestConfig::GROUP_NAME.bytes)
    path = path_replace_extname
    file_path_bytes = path.bytes
    res = (group_name + file_path_bytes)
    header[7] = (header + res).length
    res = (header + res)
    
    res[@recv_offset...@recv_offset+len].pack("C*")
  end

  def delete_file(len)
    header = ProtoCommon.header_bytes(CMD::RESP_CODE, 0)
    header.pack("C*")
  end

  def get_metadata(len)
    header = ProtoCommon.header_bytes(CMD::RESP_CODE, 0)
    body = TestConfig::METADATA.map{|a| a.join(ProtoCommon::FILE_SEPERATOR)}.join(ProtoCommon::RECORD_SEPERATOR).bytes
    header[7] = body.length
    (header + body)[@recv_offset...@recv_offset+len].pack("C*")
  end

  def set_metadata(len)
    header = ProtoCommon.header_bytes(CMD::RESP_CODE, 0)
    header.pack("C*")
  end

  def download_file(len)
    header = ProtoCommon.header_bytes(CMD::RESP_CODE, 0)
    body = IO.read(TestConfig::FILE).bytes
    header[7] = body.length
    (header + body)[@recv_offset...@recv_offset+len].pack("C*")
  end

  private 
  def path_replace_extname
    path = TestConfig::FILE_PATH
    extname = File.extname(path)
    path.gsub!(extname, ".#{@header[19..-1].reject{|i| i.zero? }.pack('C*')}")
    path
  end
end