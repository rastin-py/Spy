/// Word packs are per-language, not translated.
///
/// "Funfair" rendered into Persian is a word nobody says out loud, so the
/// Persian build ships its own pack of local words instead of a translation of
/// this one. A Persian UI never shows an English secret word - the word is the
/// thing being guessed, and a language switch would be a tell.
class WordPack {
  const WordPack({
    required this.id,
    required this.language,
    required this.name,
    required this.words,
    this.version = 1,
  });

  final String id;
  final String language;

  /// Already in the pack's own language - packs are never translated.
  final String name;
  final List<String> words;

  /// Monotonic, and the only thing that decides whether a downloaded copy
  /// replaces the one compiled in. Bundled packs start at 1 and a pack shipped
  /// from the server at 2 wins; a pack still at 1 does not, so a reinstall
  /// never re-downloads what is already in the binary.
  final int version;

  /// Parsed the same way settings are: anything that is not a usable pack
  /// comes back null rather than half a pack.
  static WordPack? tryFrom(Object? source) {
    if (source is! Map) return null;
    final id = source['id'];
    final language = source['language'];
    final name = source['name'];
    final words = source['words'];
    if (id is! String || id.isEmpty) return null;
    if (language is! String || name is! String || words is! List) return null;
    final list = words.whereType<String>().where((w) => w.trim().isNotEmpty).toList();
    if (list.isEmpty) return null;
    return WordPack(
      id: id,
      language: language,
      name: name,
      words: list,
      version: source['version'] is int ? source['version'] as int : 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'language': language,
        'name': name,
        'version': version,
        'words': words,
      };

  /// A letter in a brass square, never a picture: an icon of a "place" only
  /// invites arguments about whether a beach is one.
  String get monogram => name.characters;

  int get size => words.length;
}

extension on String {
  String get characters => isEmpty ? '?' : substring(0, 1).toUpperCase();
}

abstract final class WordPacks {
  /// The packs compiled into the binary, both languages.
  ///
  /// These are what a phone in aeroplane mode plays with, so they are never
  /// removed and never fetched - downloaded packs are additive, and a
  /// downloaded copy of one of these only counts if its version is higher.
  static const all = <WordPack>[places, foodAndDrink, objects, jobs, screen, iran];

  static List<WordPack> forLanguage(String language) =>
      all.where((p) => p.language == language).toList();

  static WordPack? byId(String id) {
    for (final pack in all) {
      if (pack.id == id) return pack;
    }
    return null;
  }

  /// The two packs a first run starts with - enough to play, few enough that
  /// the first round is not a lottery across six categories.
  static const defaultOn = <String>{'places', 'food'};

  static const places = WordPack(
    id: 'places',
    language: 'en',
    name: 'Places',
    words: [
      'Lighthouse', 'Airport', 'Hospital', 'Submarine', 'Casino', 'Library',
      'Swimming pool', 'Cemetery', 'Bank vault', 'Space station', 'Beach',
      'Cathedral', 'Police station', 'Circus', 'Hotel lobby', 'Petrol station',
      'Wine cellar', 'Rooftop', 'Subway car', 'Art gallery', 'Prison',
      'Ski lodge', 'Farmhouse', 'Nightclub', 'Bakery', 'Bowling alley',
      'Courtroom', 'Greenhouse', 'Laundromat', 'Observatory', 'Amusement park',
      'Aquarium', 'Barbershop', 'Bus station', 'Campsite', 'Car wash',
      'Castle', 'Cinema', 'Classroom', 'Construction site', 'Corner shop',
      'Dentist', 'Desert', 'Distillery', 'Dressing room', 'Ferry',
      'Fire station', 'Football stadium', 'Forest', 'Garage', 'Harbour',
      'Ice rink', 'Jungle', 'Kitchen', 'Lift', 'Market', 'Military base',
      'Mine', 'Monastery', 'Motorway', 'Museum', 'Newsroom', 'Nursery',
      'Office', 'Orchard', 'Pharmacy', 'Pier', 'Post office', 'Racetrack',
      'Radio station', 'Restaurant', 'Riverbank', 'Sauna', 'School bus',
      'Server room', 'Shopping centre', 'Stable', 'Supermarket', 'Tattoo parlour',
      'Theatre', 'Toll booth', 'Train platform', 'Tunnel', 'University',
      'Vineyard', 'Volcano', 'Waiting room', 'Waterfall', 'Windmill', 'Zoo',
    ],
  );

  static const foodAndDrink = WordPack(
    id: 'food',
    language: 'en',
    name: 'Food & drink',
    words: [
      'Pizza', 'Espresso', 'Watermelon', 'Sourdough', 'Oyster', 'Chilli',
      'Popcorn', 'Pomegranate', 'Cheesecake', 'Ramen', 'Avocado', 'Whisky',
      'Pancake', 'Saffron', 'Olive oil', 'Doughnut', 'Lemonade', 'Mushroom',
      'Steak', 'Yoghurt', 'Almond', 'Anchovy', 'Apple pie', 'Artichoke',
      'Bacon', 'Bagel', 'Baklava', 'Banana', 'Barbecue', 'Beetroot',
      'Blue cheese', 'Bubble tea', 'Butter', 'Caviar', 'Cereal', 'Champagne',
      'Cinnamon', 'Coconut', 'Cucumber', 'Curry', 'Custard', 'Dumpling',
      'Falafel', 'Fig', 'Fish and chips', 'Garlic', 'Gingerbread', 'Grapefruit',
      'Green tea', 'Honey', 'Hot sauce', 'Hummus', 'Ice cream', 'Kebab',
      'Ketchup', 'Lasagne', 'Lentil soup', 'Lobster', 'Mango', 'Maple syrup',
      'Marmalade', 'Meatball', 'Mint', 'Molasses', 'Mustard', 'Noodles',
      'Omelette', 'Onion', 'Oatmeal', 'Pasta', 'Peanut butter', 'Pickle',
      'Pineapple', 'Porridge', 'Pretzel', 'Pudding', 'Radish', 'Risotto',
      'Salmon', 'Sausage', 'Scrambled eggs', 'Seaweed', 'Sorbet', 'Soy sauce',
      'Spinach', 'Sushi', 'Taco', 'Toast', 'Truffle', 'Vinegar', 'Waffle',
    ],
  );

  static const objects = WordPack(
    id: 'objects',
    language: 'en',
    name: 'Objects',
    words: [
      'Umbrella', 'Typewriter', 'Mousetrap', 'Telescope', 'Hourglass',
      'Fire extinguisher', 'Kettle', 'Wheelbarrow', 'Chandelier', 'Harmonica',
      'Anchor', 'Ashtray', 'Backpack', 'Ballpoint pen', 'Bandage', 'Barometer',
      'Battery', 'Bicycle pump', 'Binoculars', 'Birdcage', 'Blender', 'Bookmark',
      'Bottle opener', 'Broom', 'Bucket', 'Calculator', 'Camera', 'Candle',
      'Can opener', 'Chalk', 'Chessboard', 'Clothes peg', 'Coat hanger',
      'Compass', 'Corkscrew', 'Crayon', 'Crowbar', 'Dartboard', 'Dice',
      'Doorbell', 'Drill', 'Earplugs', 'Envelope', 'Fan', 'Feather duster',
      'Fishing rod', 'Flashlight', 'Fork', 'Funnel', 'Garden hose', 'Glue',
      'Hairdryer', 'Hammer', 'Handcuffs', 'Headphones', 'Ironing board',
      'Jigsaw puzzle', 'Kaleidoscope', 'Keyring', 'Ladder', 'Lawnmower',
      'Magnet', 'Marbles', 'Megaphone', 'Metronome', 'Microscope', 'Mirror',
      'Nail clippers', 'Padlock', 'Paperclip', 'Parachute', 'Piggy bank',
      'Pillow', 'Postcard', 'Radiator', 'Razor', 'Rubber band', 'Ruler',
      'Scissors', 'Screwdriver', 'Sewing machine', 'Shoelace', 'Shovel',
      'Sponge', 'Stapler', 'Stopwatch', 'Suitcase', 'Thermometer', 'Toothbrush',
      'Torch', 'Vacuum cleaner', 'Wallet', 'Whistle', 'Wrench',
    ],
  );

  static const jobs = WordPack(
    id: 'jobs',
    language: 'en',
    name: 'Jobs',
    words: [
      'Lighthouse keeper', 'Surgeon', 'Air traffic controller', 'Beekeeper',
      'Locksmith', 'Sommelier', 'Stunt double', 'Undertaker', 'Cartographer',
      'Accountant', 'Actor', 'Ambulance driver', 'Archaeologist', 'Architect',
      'Astronaut', 'Auctioneer', 'Baker', 'Barber', 'Bartender', 'Blacksmith',
      'Bodyguard', 'Bus driver', 'Butcher', 'Carpenter', 'Chef', 'Chimney sweep',
      'Cleaner', 'Coach', 'Coastguard', 'Curator', 'Dentist', 'Detective',
      'Diplomat', 'Diver', 'Electrician', 'Farmer', 'Firefighter', 'Fisherman',
      'Florist', 'Gardener', 'Glassblower', 'Hairdresser', 'Historian',
      'Illustrator', 'Interpreter', 'Janitor', 'Jeweller', 'Journalist', 'Judge',
      'Lawyer', 'Librarian', 'Lifeguard', 'Magician', 'Mechanic', 'Midwife',
      'Miner', 'Musician', 'Nurse', 'Optician', 'Painter', 'Paramedic',
      'Pharmacist', 'Photographer', 'Pilot', 'Plumber', 'Poet', 'Postman',
      'Potter', 'Professor', 'Programmer', 'Referee', 'Sailor', 'Scientist',
      'Sculptor', 'Security guard', 'Shepherd', 'Soldier', 'Statistician',
      'Surveyor', 'Tailor', 'Tattoo artist', 'Taxi driver', 'Teacher',
      'Translator', 'Vet', 'Waiter', 'Watchmaker', 'Welder', 'Zookeeper',
    ],
  );

  static const screen = WordPack(
    id: 'screen',
    language: 'en',
    name: 'Films & television',
    words: [
      'Car chase', 'Plot twist', 'End credits', 'Cliffhanger', 'Sequel',
      'Voiceover', 'Jump scare', 'Laugh track', 'Screen test', 'Body double',
      'Action hero', 'Animation', 'Antagonist', 'Audition', 'Blockbuster',
      'Boom microphone', 'Box office', 'Cameo', 'Camera crew', 'Casting call',
      'Chase scene', 'Cinematographer', 'Clapperboard', 'Close-up', 'Costume',
      'Cult classic', 'Cut scene', 'Deleted scene', 'Dialogue', 'Director',
      'Documentary', 'Dubbing', 'Editing room', 'Extra', 'Fade to black',
      'Film festival', 'Final girl', 'Flashback', 'Foley artist', 'Franchise',
      'Green screen', 'Horror film', 'Improvisation', 'Interval', 'Leading role',
      'Live broadcast', 'Making-of', 'Matinee', 'Method actor', 'Montage',
      'Monologue', 'Musical', 'Narrator', 'Newsreader', 'Opening scene',
      'Oscar', 'Panel show', 'Period drama', 'Pilot episode', 'Popcorn queue',
      'Premiere', 'Producer', 'Prop', 'Quiz show', 'Rehearsal', 'Remake',
      'Reality show', 'Red carpet', 'Rerun', 'Review', 'Romantic comedy',
      'Rolling credits', 'Screenplay', 'Screenwriter', 'Script', 'Season finale',
      'Set design', 'Sitcom', 'Soap opera', 'Sound stage', 'Soundtrack',
      'Special effects', 'Spin-off', 'Spoiler', 'Stand-in', 'Stunt',
      'Subtitle', 'Talk show', 'Trailer', 'Wardrobe', 'Western',
    ],
  );

  /// The Persian build's own pack - local words, not a translation of Places.
  static const iran = WordPack(
    id: 'iran',
    language: 'fa',
    name: 'ایران',
    words: [
      'چلوکباب', 'قنات', 'بادگیر', 'فرش دستباف', 'سفره هفت‌سین', 'چهارشنبه‌سوری',
      'دریای خزر', 'کویر لوت', 'تخت جمشید', 'پل خواجو', 'میدان نقش جهان',
      'بازار تبریز', 'برج آزادی', 'دماوند', 'زاگرس', 'جنگل هیرکانی', 'قشم',
      'کیش', 'ماسوله', 'ابیانه', 'یزد', 'کاشان', 'شیراز', 'اصفهان', 'مشهد',
      'رشت', 'تبریز', 'کرمان', 'همدان', 'اهواز', 'بندرعباس', 'قزوین',
      'آبگوشت', 'قورمه‌سبزی', 'فسنجان', 'دیزی', 'حلیم', 'آش رشته', 'کله‌پاچه',
      'میرزاقاسمی', 'باقالی پلو', 'زرشک پلو', 'تهچین', 'دلمه', 'کوکوسبزی',
      'شله‌زرد', 'فالوده', 'بستنی زعفرانی', 'گز', 'سوهان', 'باقلوا', 'نان سنگک',
      'نان بربری', 'دوغ', 'چای نبات', 'شربت بیدمشک', 'زعفران', 'پسته', 'انار',
      'خرما', 'گلاب', 'سماور', 'قلیان', 'تسبیح', 'کرسی', 'ترمه', 'خاتم‌کاری',
      'مینیاتور', 'خوشنویسی', 'کاشی فیروزه‌ای', 'گنبد', 'حمام قدیمی', 'یخچال قدیمی',
      'تعزیه', 'نقالی', 'زورخانه', 'کشتی پهلوانی', 'سنتور', 'تار', 'نی', 'دف',
      'شعر حافظ', 'شاهنامه', 'مثنوی', 'نوروز', 'شب یلدا', 'سیزده‌بدر',
      'عیدی', 'تاکسی خطی', 'مترو تهران', 'دربند', 'توچال', 'پیکان',
    ],
  );
}
