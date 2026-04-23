/// Major Algerian cities and transit towns with GPS coordinates.
/// Used for automatic stop detection on bus routes.
class AlgeriaStop {
  final String name;
  final double lat;
  final double lng;
  const AlgeriaStop(this.name, this.lat, this.lng);
}

const List<AlgeriaStop> kAlgeriaStops = [
  // ── Algiers & Metro area ──────────────────────────────
  AlgeriaStop('Alger',             36.7372,  3.0865),
  AlgeriaStop('Rouiba',            36.7278,  3.2875),
  AlgeriaStop('Dar El Beïda',      36.7242,  3.2167),
  AlgeriaStop('Bab Ezzouar',       36.7197,  3.1847),
  AlgeriaStop('Bordj El Bahri',    36.7728,  3.1811),
  AlgeriaStop('Baraki',            36.6694,  3.1125),
  AlgeriaStop('Birtouta',          36.6444,  2.9828),
  AlgeriaStop('Meftah',            36.6206,  3.2369),
  AlgeriaStop('Khemis El Khechna', 36.6433,  3.3089),

  // ── Boumerdès wilaya ─────────────────────────────────
  AlgeriaStop('Boumerdès',         36.7667,  3.4781),
  AlgeriaStop('Boudouaou',         36.7295,  3.4070),
  AlgeriaStop('Thénia',            36.7198,  3.5596),
  AlgeriaStop('Bordj Menaïel',     36.7417,  3.7233),
  AlgeriaStop('Baghlia',           36.6369,  3.5756),
  AlgeriaStop('Timezrit',          36.6578,  3.8781),
  AlgeriaStop('Naciria',           36.6939,  3.8194),

  // ── Bouira wilaya & N5 corridor ───────────────────────
  AlgeriaStop('Lakhdaria',         36.5574,  3.5872),
  AlgeriaStop('Kadiria',           36.5272,  3.6694),
  AlgeriaStop('Bouira',            36.3704,  3.9001),
  AlgeriaStop('Aïn Bessam',        36.3322,  3.6681),
  AlgeriaStop('Sour El Ghouzlane', 36.1486,  3.6836),
  AlgeriaStop('M\'Chedallah',      36.3719,  4.2661),
  AlgeriaStop('Haïzer',            36.3908,  3.8200),
  AlgeriaStop('El Asnam (Bouira)', 36.2939,  3.7947),

  // ── Blida & south of Algiers ─────────────────────────
  AlgeriaStop('Blida',             36.4714,  2.8277),
  AlgeriaStop('Boufarik',          36.5706,  2.9188),
  AlgeriaStop('Larbaâ',            36.5608,  3.1647),
  AlgeriaStop('Bougara',           36.5411,  3.0808),
  AlgeriaStop('El Affroun',        36.4667,  2.6283),
  AlgeriaStop('Chiffa',            36.4025,  2.6942),
  AlgeriaStop('Beni Mered',        36.5300,  2.8867),
  AlgeriaStop('Oued El Alleug',    36.5044,  2.7481),

  // ── Médéa axis ───────────────────────────────────────
  AlgeriaStop('Médéa',             36.2639,  2.7539),
  AlgeriaStop('Berrouaghia',       35.8994,  2.9094),
  AlgeriaStop('Ksar El Boukhari',  35.8694,  3.0622),
  AlgeriaStop('Ouled Slama',       36.1394,  2.8644),
  AlgeriaStop('Aïn Oussera',       35.4494,  2.9058),
  AlgeriaStop('Tablat',            36.4286,  3.3200),

  // ── Tipaza axis ──────────────────────────────────────
  AlgeriaStop('Tipaza',            36.5894,  2.4478),
  AlgeriaStop('Cherchell',         36.6039,  2.1911),
  AlgeriaStop('Hadjout',           36.5117,  2.5294),
  AlgeriaStop('Koléa',             36.6375,  2.7661),

  // ── Aïn Defla / Chlef axis ───────────────────────────
  AlgeriaStop('Aïn Defla',         36.2644,  1.9670),
  AlgeriaStop('Miliana',           36.3017,  2.2344),
  AlgeriaStop('Khemis Miliana',    36.2644,  2.2208),
  AlgeriaStop('Chlef',             36.1650,  1.3317),
  AlgeriaStop('Boukadir',          36.0747,  1.1303),
  AlgeriaStop('Oued Fodda',        36.1803,  1.5325),

  // ── Tizi Ouzou axis ──────────────────────────────────
  AlgeriaStop('Tizi Ouzou',        36.7169,  4.0497),
  AlgeriaStop('Azazga',            36.7397,  4.3725),
  AlgeriaStop('Tizi Gheniff',      36.6433,  3.7783),
  AlgeriaStop('Boghni',            36.5417,  3.9519),
  AlgeriaStop('Draa El Mizan',     36.5344,  3.8356),
  AlgeriaStop('Makouda',           36.7467,  3.9244),
  AlgeriaStop('Larbaa Nath Irathen', 36.6978, 4.1903),
  AlgeriaStop('Ouadhia',           36.4783,  4.0683),
  AlgeriaStop('Ain El Hammam',     36.5669,  4.3083),

  // ── Béjaïa axis ──────────────────────────────────────
  AlgeriaStop('Béjaïa',            36.7525,  5.0567),
  AlgeriaStop('Sidi Aïch',         36.6300,  4.6975),
  AlgeriaStop('El Kseur',          36.6789,  4.8569),
  AlgeriaStop('Amizour',           36.6428,  4.9033),
  AlgeriaStop('Akbou',             36.4647,  4.5283),
  AlgeriaStop('Kherrata',          36.5028,  5.2553),
  AlgeriaStop('Aokas',             36.6731,  5.2067),

  // ── Sétif & BBA axis ─────────────────────────────────
  AlgeriaStop('Sétif',             36.1898,  5.4100),
  AlgeriaStop('Bordj Bou Arréridj', 36.0731, 4.7630),
  AlgeriaStop('Aïn El Kebira',     36.3408,  5.0725),
  AlgeriaStop('El Eulma',          36.1497,  5.6917),
  AlgeriaStop('Aïn Oulmène',       35.9117,  5.2978),
  AlgeriaStop('Beni Aziz',         36.2781,  5.3083),
  AlgeriaStop('Bir El Arch',       35.9533,  5.7519),

  // ── Constantine & Far East ───────────────────────────
  AlgeriaStop('Constantine',       36.3650,  6.6147),
  AlgeriaStop('Mila',              36.4500,  6.2667),
  AlgeriaStop('Guelma',            36.4617,  7.4328),
  AlgeriaStop('Annaba',            36.9000,  7.7667),
  AlgeriaStop('Skikda',            36.8761,  6.9078),
  AlgeriaStop('El Harrouch',       36.6992,  6.8433),
  AlgeriaStop('Oum El Bouaghi',    35.8769,  7.1136),
  AlgeriaStop('Aïn Beïda',         35.7958,  7.3956),
  AlgeriaStop('Tébessa',           35.4033,  8.1200),
  AlgeriaStop('Souk Ahras',        36.2864,  7.9511),
  AlgeriaStop('El Tarf',           36.7673,  8.3115),
  AlgeriaStop('Jijel',             36.8200,  5.7658),
  AlgeriaStop('Collo',             37.0000,  6.5608),
  AlgeriaStop('Azzaba',            36.7397,  7.1050),
  AlgeriaStop('El Khroub',         36.2761,  6.6908),
  AlgeriaStop('Ain Smara',         36.3511,  6.7456),

  // ── Oran & West ──────────────────────────────────────
  AlgeriaStop('Oran',              35.6969, -0.6331),
  AlgeriaStop('Mostaganem',        35.9317,  0.0892),
  AlgeriaStop('Relizane',          35.7378,  0.5617),
  AlgeriaStop('Mascara',           35.3956,  0.1403),
  AlgeriaStop('Sidi Bel Abbès',    35.1900, -0.6330),
  AlgeriaStop('Tlemcen',           34.8786, -1.3156),
  AlgeriaStop('Ain Temouchent',    35.2975, -1.1403),
  AlgeriaStop('Sig',               35.5286, -0.1914),
  AlgeriaStop('Tiaret',            35.3706,  1.3217),
  AlgeriaStop('Tissemsilt',        35.6075,  1.8117),
  AlgeriaStop('Frenda',            35.0594,  1.0392),
  AlgeriaStop('Ghilizane',         35.7378,  0.5617),
  AlgeriaStop('Sidi Ali',          36.0989,  0.3003),
  AlgeriaStop('Es Sénia',          35.6494, -0.6039),
  AlgeriaStop('Ain El Turk',       35.7431, -0.7711),

  // ── South / Hauts Plateaux ───────────────────────────
  AlgeriaStop('Laghouat',          33.7972,  2.8824),
  AlgeriaStop('Djelfa',            34.6706,  3.2631),
  AlgeriaStop('Messaad',           34.1533,  3.4994),
  AlgeriaStop('Batna',             35.5560,  6.1738),
  AlgeriaStop('Biskra',            34.8500,  5.7333),
  AlgeriaStop('M\'Sila',           35.7000,  4.5369),
  AlgeriaStop('Bou Saâda',         35.2069,  4.1853),
  AlgeriaStop('Ouargla',           31.9497,  5.3246),
  AlgeriaStop('Ghardaïa',          32.4908,  3.6731),
  AlgeriaStop('El Oued',           33.3567,  6.8633),
  AlgeriaStop('Touggourt',         33.1003,  6.0678),
  AlgeriaStop('Khenchela',         35.4358,  7.1431),
  AlgeriaStop('Barika',            35.3886,  5.3736),
  AlgeriaStop('N\'Gaous',          35.5183,  5.6003),
];
