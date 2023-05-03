defmodule Types.ImageTypeTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: false
  alias Tds.Parameter

  setup do
    {:ok, pid} = Tds.start_link(opts())

    {:ok, [pid: pid]}
  end

  # load image from file
  def load_image(path) do
    File.read!(path)
  end

  test "Should store image data to column", context do
    query("DROP TABLE IF EXISTS [dbo].[Images]", [])

    query(
      """
        CREATE TABLE [dbo].[Images](
          [Id] [int] IDENTITY(1,1) NOT NULL,
          [Name] [nvarchar](50) NOT NULL,
          [Data] [image] NOT NULL,
          [Data2] [image] NULL,
          CONSTRAINT [PK_Images] PRIMARY KEY CLUSTERED ([Id] ASC)
        ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
      """,
      []
    )

    image = load_image("test/fixtures/images/elixir-logo.png")

    params = [
      %Parameter{name: "@1", value: "Elixir Logo", type: :string},
      %Parameter{name: "@2", value: image, type: :image},
      %Parameter{name: "@3", value: nil, type: :image}
    ]

    :ok =
      query(
        """
          INSERT INTO [dbo].[Images] ([Name], [Data], [Data2])
          VALUES (@1, @2, @3)
        """,
        params
      )

    {:ok, result} =
      Tds.query(context[:pid], "SELECT [Id], [Name], [Data], [Data2] FROM [dbo].[Images]", [])

    assert result == %Tds.Result{
             columns: ["Id", "Name", "Data", "Data2"],
             num_rows: 1,
             rows: [
               [1, "Elixir Logo", image, nil]
             ]
           }
  end
end
