describe LivereloadRails::WebSocket, timeout: 1 do
  let(:klass) { LivereloadRails::WebSocket }

  let(:channel) { UNIXSocket.pair }
  let(:remote) { channel[0] }
  let(:local)  { channel[1] }

  let(:env) do
    {
      "rack.hijack?" => true,
      "rack.hijack" => lambda { env["rack.hijack_io"] = local }
    }
  end

  let(:fail) do
    proc { raise "this should never run" }
  end

  let(:standard_error) { StandardError.new("HI!") }

  describe ".from_rack" do
    it "returns nil if not a websocket connection" do
      expect(klass.from_rack({})).to eq(nil)
    end
  end

  describe "#initialize" do

    it "yields to the given setup block completely before returning" do
      setup = nil

      klass.new(env) { setup = Thread.current }

      expect(setup).to be_a(Thread)
      expect(setup).to_not eq(Thread.current)
    end

    it "raises an error if hijacking is not supported" do
      env["rack.hijack?"] = false
      expect { klass.new(env, &fail) }.to raise_error(LivereloadRails::HijackingNotSupported)
    end

    it "raises an error if no block was given" do
      expect { klass.new(env) }.to raise_error(ArgumentError, "no block given")
    end

    it "raises an error if hijacking failed (partial hijacking)" do
      env = {
        "rack.hijack?" => true,
        "rack.hijack" => lambda { raise NotImplementedError }
      }

      expect { klass.new(env) {} }.to raise_error(NotImplementedError)
    end

    it "raises an error if setup fails" do
      expect {
        klass.new(env) { |ws| raise standard_error }
      }.to raise_error(standard_error)
    end

    it "does not raise an error if handshaking fails" do
      env["HTTP_SEC_WEBSOCKET_VERSION"] = "1337"

      websocket = klass.new(env) { |ws| }
      expect { websocket.thread.join }.to raise_error
    end
  end

  describe "events" do
    let(:env) do
      super().merge(handshake_env(url: "ws://example.org/"))
    end

    let(:q) { Queue.new }

    let(:handler) do
      lambda do |ws|
        ws.on(:open) { |*args| q << [:open, *args] }
        ws.on(:message) { |*args| q << [:message, *args] }
        ws.on(:close) { |*args| q << [:close, *args] }
      end
    end

    def consume_queue(length)
      length.times.map { q.pop }
    ensure
      expect(q).to be_empty
    end

    describe ":open" do
      it "is triggered once with no arguments on connection initiation" do
        websocket = klass.new(env, &handler)
        expect(consume_queue(1)).to match([[:open]])
      end

      it "is not triggered on handshake error" do
        env["HTTP_SEC_WEBSOCKET_VERSION"] = "1337"

        websocket = klass.new(env, &handler)
        expect(consume_queue(1)).to match([[:close, a_kind_of(WebSocket::Error::Handshake::UnknownVersion)]])
      end
    end

    specify ":message is triggered on every input frame" do
      websocket = klass.new(env, &handler)
      expect(consume_queue(1)).to eq([[:open]])
      remote.write ws_frame("YARR YE LANDLUBBERS") + ws_frame("WOOHOOO!", type: :binary)

      first, second = consume_queue(2)

      expect(first[0]).to eq(:message)
      expect(first[1].type).to eq(:text)
      expect(first[1].data).to eq("YARR YE LANDLUBBERS")

      expect(second[0]).to eq(:message)
      expect(second[1].type).to eq(:binary)
      expect(second[1].data).to eq("WOOHOOO!")
    end

    describe ":close" do
      it "is triggered on graceful remote shutdown" do
        websocket = klass.new(env, &handler)
        expect(consume_queue(1)).to eq([[:open]])

        remote.close
        websocket.thread.join

        expect(consume_queue(1)).to eq([[:close]])
      end

      it "is triggered on graceful local shutdown" do
        websocket = klass.new(env, &handler)
        expect(consume_queue(1)).to eq([[:open]])

        websocket.close
        websocket.thread.join

        expect(consume_queue(1)).to eq([[:close]])
      end

      it "is triggered on catastrophic shutdown", timeout: nil do
        websocket = klass.new(env) do |ws|
          handler[ws]
          ws.on(:message) { raise standard_error }
        end

        remote.write ws_frame("BYE BYE!")
        expect { websocket.thread.join }.to raise_error(standard_error)
        expect(consume_queue(3)).to match([[:open], [:message, a_value], [:close, standard_error]])
      end

      it "is triggered on setup failure" do
        expect {
          klass.new(env) do |ws|
            handler[ws]
            raise standard_error
          end
        }.to raise_error(standard_error)

        expect(consume_queue(1)).to match([[:close, standard_error]])
      end

      it "is triggered if handshaking fails" do
        env["HTTP_SEC_WEBSOCKET_VERSION"] = "1337"

        websocket = klass.new(env, &handler)
        expect(consume_queue(1)).to match([[:close, a_kind_of(WebSocket::Error::Handshake::UnknownVersion)]])
      end
    end

    describe "#on" do
      it "raises an error if the event does not exist" do
        websocket = klass.new(env, &handler)
        expect { websocket.on(:what) }.to raise_error(ArgumentError, /what/)
      end
    end
  end

  describe "parsing" do
    specify "multiple websocket frames may arrive in a single packet"
    specify "continuation websocket frames are properly concatenated"

    specify "ping frames are handled by responding with pong"
    specify "close frames are handled by closing the connection"
    specify "text frames are yielded to the handler"
    specify "binary frames are yielded to the handler"

    # TODO: client error, should it really raise a server-side error? maybe for logging
    specify "unknown frames closes the connection"
  end

  describe "#write" do
    it "can write arbitrary websocket frames"
  end

  describe "#close" do
    it "can be called multiple times"
    it "can be called at any time to close the connection"
  end
end
