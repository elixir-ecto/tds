defmodule BinaryTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: false
  alias Tds.Parameter

  @pangrams [
    [
      "Danish_Greenlandic_100_CI_AS_KS_WS",
      "Quizdeltagerne spiste jordbær med fløde, mens cirkusklovnen. Wolther spillede på xylofon."
    ],
    [
      "German_PhoneBook_CI_AS_KS_WS",
      "Falsches Üben von Xylophonmusik quält jeden größeren Zwerg. Zwölf Boxkämpfer jagten Eva quer über den Sylter Deich. Heizölrückstoßabdämpfung"
    ],
    [
      "Greek_CI_AS_KS_WS",
      "Γαζέες καὶ μυρτιὲς δὲν θὰ βρῶ πιὰ στὸ χρυσαφὶ ξέφωτο. Ξεσκεπάζω τὴν ψυχοφθόρα βδελυγμία."
    ],
    ["English", "The quick brown fox jumps over the lazy dog"],
    [
      "Modern_Spanish_CI_AS_KS_WS",
      "El pingüino Wenceslao hizo kilómetros bajo exhaustiva lluvia y frío, añoraba a su querido cachorro."
    ],
    [
      "French_CI_AS_KS",
      "Portez ce vieux whisky au juge blond qui fume sur son île intérieure, à côté de l'alcôve ovoïde, où " <>
        "les bûches se consument dans l'âtre, ce qui lui permet de penser à la cænogenèse de l'être dont il est " <>
        "question dans la cause ambiguë entendue à Moÿ, dans un capharnaüm qui, pense-t-il, diminue çà et " <>
        "là la qualité de son œuvre. l'île exiguë Où l'obèse jury mûr Fête l'haï volapük, Âne ex aéquo au whist, " <>
        "Ôtez ce vœu déçu. Le cœur déçu mais l'âme plutôt naïve, Louÿs rêva de crapaüter en canoë au delà des " <>
        "îles, près du mälström où brûlent les novæ."
    ],
    ["Hungarian_CI_AS_KS", "Árvíztűrő tükörfúrógép"],
    [
      "Icelandic_CI_AS",
      "Kæmi ný öxi hér ykist þjófum nú bæði víl og ádrepa Sævör grét áðan því úlpan var ónýt"
    ],
    [
      "Japanese_CI_AS_KS_WS",
      """
      いろはにほへとちりぬるを
      わかよたれそつねならむ
      うゐのおくやまけふこえて
      あさきゆめみしゑひもせす
      """
    ],
    [
      "Japanese_CI_AS_KS_WS",
      """
      イロハニホヘト チリヌルヲ ワカヨタレソ ツネナラム
      ウヰノオクヤマ ケフコエテ アサキユメミシ ヱヒモセスン
      """
    ],
    ["Hebrew_100_CI_AS", "דג סקרן שט בים מאוכזב ולפתע מצא לו חברה איך הקליטה"],
    ["Polish_100_CI_AS", "Pchnąć w tę łódź jeża lub ośm skrzyń fig"],
    [
      "Cyrillic_General_100_CS_AS",
      "В чащах юга жил бы цитрус? Да, но фальшивый экземпляр! Съешь же ещё этих мягких французских булок да выпей чаю"
    ],
    [
      "Thai_100_CI_AS",
      # [The copyright for the Thai example is owned by The Computer Association of Thailand under the Royal Patronage of His Majesty the King.]
      """
      [--------------------------|------------------------]
      ๏ เป็นมนุษย์สุดประเสริฐเลิศคุณค่า  กว่าบรรดาฝูงสัตว์เดรัจฉาน
      จงฝ่าฟันพัฒนาวิชาการ           อย่าล้างผลาญฤๅเข่นฆ่าบีฑาใคร
      ไม่ถือโทษโกรธแช่งซัดฮึดฮัดด่า     หัดอภัยเหมือนกีฬาอัชฌาสัย
      ปฏิบัติประพฤติกฎกำหนดใจ        พูดจาให้จ๊ะๆ จ๋าๆ น่าฟังเอย ฯ
      """
    ],
    [
      "Chinese_Simplified_Pinyin_100_CI_AI_KS",
      "鐵腕・都鐸王朝（五）：文藝復興最懂穿搭的高富帥——亨利八世"
    ],
    [
      "Indic_General_100_CI_AS",
      "कः खगौघाङचिच्छौजा झाञ्ज्ञोऽटौठीडडण्ढणः। तथोदधीन् पफ र्बाभीर्मयोऽरिल्वाशिषां सहः।।"
    ],
    [
      "Serbian_Latin_100_CI_AS",
      "Gojazni đačić s biciklom drži hmelj i finu vatu u džepu nošnje"
    ],
    [
      "Serbian_Cyrillic_100_CI_AS",
      "Љубазни фењерџија чађавог лица хоће да ми покаже штос"
    ]
  ]

  @tag timeout: 50000

  setup do
    opts = Application.fetch_env!(:tds, :opts)
    {:ok, pid} = Tds.start_link(opts)

    {:ok, [pid: pid]}
  end

  test "Implicit Conversion of binary to datatypes", context do
    query("DROP TABLE bin_test", [])

    query(
      """
        CREATE TABLE bin_test (
          char char NULL,
          varchar varchar(max) NULL,
          nvarchar nvarchar(max) NULL,
          bin_nvarchar nvarchar(max) NULL,
          binary binary NULL,
          varbinary varbinary(max) NULL,
          uuid uniqueidentifier NULL
          )
      """,
      []
    )

    nvar = "World" |> :unicode.characters_to_binary(:utf8, {:utf16, :little})

    params = [
      %Parameter{name: "@1", value: "H", type: :binary},
      %Parameter{name: "@2", value: "ello", type: :string},
      %Parameter{name: "@3", value: "World", type: :string},
      %Parameter{name: "@4", value: nvar, type: :binary},
      %Parameter{name: "@5", value: <<0>>, type: :binary},
      %Parameter{name: "@6", value: <<0, 1, 0, 1>>, type: :binary},
      %Parameter{
        name: "@7",
        value: <<
          0x82,
          0x25,
          0xF2,
          0xA9,
          0xAF,
          0xBA,
          0x45,
          0xC5,
          0xA4,
          0x31,
          0x86,
          0xB9,
          0xA8,
          0x67,
          0xE0,
          0xF7
        >>,
        type: :uuid
      }
    ]

    query(
      """
      INSERT INTO bin_test
      (char, varchar, nvarchar, bin_nvarchar, binary, varbinary, uuid)
      VALUES (@1, @2, @3, @4, @5, @6, @7)
      """,
      params
    )

    assert [
             [
               "H",
               "ello",
               "World",
               "World",
               <<0>>,
               <<0, 1, 0, 1>>,
               <<
                 0x82,
                 0x25,
                 0xF2,
                 0xA9,
                 0xAF,
                 0xBA,
                 0x45,
                 0xC5,
                 0xA4,
                 0x31,
                 0x86,
                 0xB9,
                 0xA8,
                 0x67,
                 0xE0,
                 0xF7
               >>
             ]
           ] = query("SELECT TOP(1) * FROM bin_test", [])

    # query("DROP TABLE bin_test", [])
  end

  test "Support large binary with length over 8000", context do
    value =
      "W"
      |> String.duplicate(9000)
      |> :unicode.characters_to_binary(:utf8, {:utf16, :little})

    """
    DROP TABLE bin_test
    CREATE TABLE bin_test (varbinary varbinary(max) NULL)
    INSERT INTO bin_test (varbinary) VALUES (@1)
    """
    |> query([
      %Parameter{name: "@1", value: value, type: :binary}
    ])

    assert [[^value]] = query("SELECT TOP(1) * FROM bin_test", [])
  end

  test "Binary NULL Types", context do
    query("DROP TABLE bin_test", [])

    query(
      """
        CREATE TABLE bin_test (
          char char NULL,
          varchar varchar(max) NULL,
          nvarchar nvarchar(max) NULL,
          binary binary NULL,
          varbinary varbinary(max) NULL,
          uuid uniqueidentifier NULL
          )
      """,
      []
    )

    params = [
      %Parameter{name: "@1", value: nil, type: :binary},
      %Parameter{name: "@2", value: nil, type: :binary},
      %Parameter{name: "@3", value: nil, type: :binary},
      %Parameter{name: "@4", value: nil, type: :binary},
      %Parameter{name: "@5", value: nil, type: :binary},
      %Parameter{name: "@6", value: nil, type: :binary}
    ]

    query(
      """
      INSERT INTO bin_test
      (char, varchar, nvarchar, binary, varbinary, uuid)
      VALUES (@1, @2, @3, @4, @5, @6)
      """,
      params
    )

    assert [[nil, nil, nil, nil, nil, nil]] = query("SELECT TOP(1) * FROM bin_test", [])
  end

  test "strings as nvarchar", context do
    Application.put_env(:tds, :text_encoder, Tds.Encoding)
    query("DROP TABLE pangrams", [])

    query(
      """
      CREATE TABLE pangrams (
        [id] int identity(1,1) not null primary key,
        [lang] varchar(255),
        [pangram] nvarchar(max)
      )
      """,
      []
    )

    @pangrams
    |> Enum.each(fn [lang, pangram] ->
      query(
        "insert into pangrams values (@1, @2)",
        [
          %Parameter{name: "@1", value: lang, type: :varchar},
          %Parameter{name: "@2", value: pangram, type: :string}
        ]
      )
    end)

    assert @pangrams == query("select [lang], [pangram] from pangrams", [])
    Application.delete_env(:tds, :text_encoder)
  end
end
