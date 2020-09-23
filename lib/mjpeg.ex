defmodule Mjpeg do
  @moduledoc """
  Documentation for `Mjpeg`.
  """

  import Plug.Conn
  require Logger

  @boundary "w58EW1cEpjzydSCq"

  def init(opts), do: opts

  def call(conn, opts) do
    connect = Keyword.get(opts, :connect_callback, nil)
    wait = Keyword.get(opts, :wait_callback, nil)

    if is_nil(connect) or is_nil(wait) do
      raise "Need both :connect_callback and :wait_callback in options."
    end

    context = connect.(conn, opts)

    conn
    |> send_start()
    |> wait_for_frame(wait, context)
  end

  def send_frame(conn, jpeg_data, context) do
    size = byte_size(jpeg_data)
    header = "------#{@boundary}\r\nContent-Type: image/jpeg\r\nContent-length: #{size}\r\n\r\n"
    footer = "\r\n"

    with {:ok, conn} <- chunk(conn, header),
         {:ok, conn} <- chunk(conn, jpeg_data),
         {:ok, conn} <- chunk(conn, footer) do
      Logger.info("Frame sent: #{inspect(self())}")
      conn
    else
      _ ->
        context.error_callback()
    end
  end

  defp wait_for_frame(conn, wait, context) do
    frame = wait.(context)

    conn
    |> send_frame(frame, context)
    |> wait_for_frame(wait, context)
  end

  defp send_start(conn) do
    conn
    |> put_resp_header("Age", "0")
    |> put_resp_header("Cache-Control", "no-cache, private")
    |> put_resp_header("Pragma", "no-cache")
    |> put_resp_header("Content-Type", "multipart/x-mixed-replace; boundary=#{@boundary}")
    |> send_chunked(200)
  end
end
