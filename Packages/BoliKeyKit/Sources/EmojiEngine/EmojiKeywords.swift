/// Words people type, in Hinglish, English and Hindi, and the emoji that go with them, best first.
///
/// Written for BoliKey. One line per idea: `keyword keyword | emoji emoji`. Keywords are lowercase
/// and appear once. Everyday words such as `hai`, `ok`, `bhai` and `kaam` are left out on purpose:
/// they come up in nearly every message, and an emoji for each would crowd out the word suggestions.
enum EmojiKeywords {
    static let table = """
    # Love
    dil heart | ❤️ 💖 💕
    pyaar pyar love luv ishq mohabbat prem | ❤️ 😍 🥰
    jaan jaanu janu babu baby shona | 😘 ❤️ 🥰
    miss missyou | 🥺 ❤️
    kiss chumma | 😘 💋
    hug jhappi | 🤗
    crush | 😍 🙈
    cute | 🥰 😊
    # Laughing
    haha hahaha hahahaha hehe lol lmao rofl hasi hassi hansi | 😂 🤣 😆
    mazak mazaak joke jokes funny | 😂 😜
    masti fun | 😜 🥳
    # Happy
    khush khushi happy maza mazaa mast | 😊 😄 😁
    smile muskaan muskan | 😊 🙂
    cool chill | 😎
    awesome zabardast kamaal badhiya badiya shandaar shandar superb amazing great | 🔥 👏 🤩
    wow waah wah | 🤩 😮 👏
    perfect | 💯 👌
    # Sad
    dukhi sad udaas udas | 😢 😔 💔
    rona cry crying | 😭 😢
    dard pain hurt | 💔 😣
    tension stress | 😩 😰
    bore bored boring | 🥱 😴
    thak thaka thaki thakan tired | 😩 🥱
    # Angry
    gussa gusa angry naraz naraaz | 😡 😠 😤
    # Surprised, scared, thinking
    darr scared fear | 😨 😱
    shock shocked omg | 😱 😮
    soch hmm hmmm think thinking | 🤔
    confused confuse | 😕 🤔
    pagal crazy | 🤪
    sharam shame shy | 🙈 😳
    chup secret raaz | 🤫
    # Sleep and greetings
    neend sleep sleepy | 😴 💤
    gn goodnight night shubhratri | 🌙 😴
    gm goodmorning morning subah | ☀️ 🌅
    thanks thank thankyou thanku thnx thx shukriya dhanyavaad dhanyawad | 🙏 😊
    sorry maaf maafi | 🙏 😔
    namaste namaskar pranam | 🙏
    please plz pls | 🙏 🥺
    hello hey bye tata alvida | 👋
    welcome swagat | 🤗 🙏
    congrats congratulations badhai badhaai mubarak | 🎉 👏 🥳
    luck goodluck | 🤞 🍀
    pakka deal promise vaada wada | 🤝
    clap | 👏
    strong power taakat takat | 💪
    dua pray prayer bhagwan bhagwaan god | 🙏
    # Celebrations
    party | 🎉 🥳 🍻
    birthday bday hbd janamdin | 🎂 🎉 🎁
    gift tohfa | 🎁
    diwali deepawali | 🪔 ✨ 🎆
    holi | 🎨 🌈
    eid | 🌙 🕌
    christmas xmas | 🎄 🎅
    newyear | 🎆 🥳
    shaadi shadi wedding marriage | 💍 🎉
    rakhi | 🎁 ❤️
    festival tyohar tyohaar | 🎉 🪔
    win jeet victory | 🏆 🥇
    # Food and drink
    chai tea coffee | ☕
    khana khaana food | 🍛 😋
    bhookh bhook hungry | 😋 🍽️
    pizza | 🍕
    burger | 🍔
    biryani | 🍛
    cake | 🎂 🍰
    mithai sweets | 🍬 🍰
    icecream | 🍦
    paani pani water | 💧
    daaru daru beer drinks | 🍻 🍺
    mango | 🥭
    # Places and travel
    ghar home | 🏠
    office | 💼 💻
    school | 🏫
    college | 🎓
    exam exams padhai study | 📚 ✍️
    trip travel safar | ✈️ 🧳
    chutti chhutti holiday vacation | 🏖️ 🥳
    flight | ✈️
    train | 🚆
    car gaadi gaddi | 🚗
    bike | 🏍️
    auto | 🛺
    beach | 🏖️
    mandir temple | 🛕
    masjid | 🕌
    # Weather
    baarish barish rain | 🌧️ ☔
    garmi | 🥵 ☀️
    thand thandi sardi cold | 🥶 ❄️
    dhoop sunny | ☀️
    # Sport and fun
    cricket | 🏏
    football | ⚽
    gaana gana song music | 🎵 🎶
    dance naach nach | 💃 🕺
    movie film | 🎬 🍿
    game gaming | 🎮
    gym workout | 💪
    # Things
    paisa paise money cash salary | 💰 💵
    shopping | 🛍️ 🛒
    photo pic selfie | 📸
    aag fire lit | 🔥
    bimar beemar sick fever bukhar | 🤒
    doctor | 🩺
    kutta dog | 🐶
    billi cat | 🐱
    phool flower | 🌸 🌹
    gulab rose | 🌹
    chand chaand moon | 🌙
    star | ⭐
    idea | 💡
    kitab kitaab book | 📚
    late der | ⏰
    india bharat hindustan | 🇮🇳
    # Hindi
    दिल | ❤️
    प्यार | ❤️ 😍
    खुश | 😊
    दुखी | 😢
    गुस्सा | 😡
    चाय | ☕
    खाना | 🍛
    जन्मदिन | 🎂 🎉
    दिवाली | 🪔 ✨
    होली | 🎨
    धन्यवाद शुक्रिया | 🙏
    नमस्ते | 🙏
    पार्टी | 🎉
    """
}
