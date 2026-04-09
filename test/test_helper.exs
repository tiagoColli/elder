Mox.stub(Elder.LLM.ClientMock, :stream, fn _context, _model, _topic -> :ok end)
Mox.stub(Elder.LLM.ClientMock, :call, fn _context, _model, _topic -> :ok end)

ExUnit.start()
