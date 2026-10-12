// Demo catalog for offline UI development only.
// Production prices/products must come from VTpass (vtu-verify/vtu-pay Edge
// Functions) or a server-driven catalog. Do not treat these as live prices.
import 'models.dart';

class Product {
  final String id;
  final String name;
  final String subtitle;
  final int priceKobo;
  final String? badge;
  final String? category;
  const Product({required this.id, required this.name, required this.subtitle, required this.priceKobo, this.badge, this.category});
}

class ProviderDef {
  final String id;
  final String name;
  final String shortName;
  final String accent; // yellow, red, green, teal, blue, navy, orange
  final String? inputLabel;
  final String? inputPlaceholder;
  final List<Product>? products;
  const ProviderDef({required this.id, required this.name, required this.shortName, required this.accent, this.inputLabel, this.inputPlaceholder, this.products});
}

const List<Product> _dataPlans = [
  Product(id: 'daily-500mb', name: '500 MB', subtitle: '1 day · Data bundle', priceKobo: 25000, badge: 'Daily', category: 'Daily'),
  Product(id: 'daily-1gb', name: '1 GB', subtitle: '1 day · Data bundle', priceKobo: 50000, badge: 'Popular', category: 'Daily'),
  Product(id: 'weekly-2gb', name: '2 GB', subtitle: '7 days · Data bundle', priceKobo: 100000, badge: 'Weekly', category: 'Weekly'),
  Product(id: 'monthly-5gb', name: '5 GB', subtitle: '30 days · Monthly plan', priceKobo: 250000, category: 'Monthly'),
  Product(id: 'monthly-10gb', name: '10 GB', subtitle: '30 days · Monthly plan', priceKobo: 450000, badge: 'Best value', category: 'Monthly'),
];

final Map<ServiceKind, List<ProviderDef>> providersByKind = {
  ServiceKind.airtime: const [
    ProviderDef(id: 'mtn', name: 'MTN Nigeria', shortName: 'MTN', accent: 'yellow'),
    ProviderDef(id: 'airtel', name: 'Airtel Nigeria', shortName: 'Airtel', accent: 'red'),
    ProviderDef(id: 'glo', name: 'Globacom', shortName: 'Glo', accent: 'green'),
    ProviderDef(id: '9mobile', name: '9mobile', shortName: '9mobile', accent: 'teal'),
  ],
  ServiceKind.data: const [
    ProviderDef(id: 'mtn', name: 'MTN Nigeria', shortName: 'MTN', accent: 'yellow', products: _dataPlans),
    ProviderDef(id: 'airtel', name: 'Airtel Nigeria', shortName: 'Airtel', accent: 'red', products: _dataPlans),
    ProviderDef(id: 'glo', name: 'Globacom', shortName: 'Glo', accent: 'green', products: _dataPlans),
    ProviderDef(id: '9mobile', name: '9mobile', shortName: '9mobile', accent: 'teal', products: _dataPlans),
  ],
  ServiceKind.electricity: [
    for (int i = 0; i < _discos.length; i++)
      ProviderDef(id: _discos[i].toLowerCase(), name: _discos[i], shortName: _discos[i], accent: i % 2 == 1 ? 'orange' : 'blue'),
  ],
  ServiceKind.cable: const [
    ProviderDef(id: 'dstv', name: 'DStv', shortName: 'DStv', accent: 'blue', inputLabel: 'Smartcard number', inputPlaceholder: 'Enter 10-digit smartcard number', products: [
      Product(id: 'dstv-padi', name: 'DStv Padi', subtitle: '45+ channels · 30 days', priceKobo: 440000),
      Product(id: 'dstv-yanga', name: 'DStv Yanga', subtitle: '85+ channels · 30 days', priceKobo: 600000, badge: 'Popular'),
      Product(id: 'dstv-confam', name: 'DStv Confam', subtitle: '105+ channels · 30 days', priceKobo: 1100000),
    ]),
    ProviderDef(id: 'gotv', name: 'GOtv', shortName: 'GOtv', accent: 'green', inputLabel: 'IUC number', inputPlaceholder: 'Enter 10-digit IUC number', products: [
      Product(id: 'gotv-smallie', name: 'GOtv Smallie', subtitle: '35+ channels · 30 days', priceKobo: 190000),
      Product(id: 'gotv-jolli', name: 'GOtv Jolli', subtitle: '65+ channels · 30 days', priceKobo: 580000, badge: 'Popular'),
      Product(id: 'gotv-max', name: 'GOtv Max', subtitle: '75+ channels · 30 days', priceKobo: 850000),
    ]),
    ProviderDef(id: 'startimes', name: 'StarTimes', shortName: 'StarTimes', accent: 'orange', inputLabel: 'Smartcard number', inputPlaceholder: 'Enter smartcard number', products: [
      Product(id: 'nova', name: 'Nova', subtitle: '30+ channels · 30 days', priceKobo: 170000),
      Product(id: 'basic', name: 'Basic', subtitle: '45+ channels · 30 days', priceKobo: 330000),
      Product(id: 'classic', name: 'Classic', subtitle: '60+ channels · 30 days', priceKobo: 500000, badge: 'Popular'),
    ]),
  ],
  ServiceKind.education: const [
    ProviderDef(id: 'waec', name: 'WAEC', shortName: 'WAEC', accent: 'navy', inputLabel: 'Candidate name', inputPlaceholder: 'Enter candidate name', products: [Product(id: 'waec-result', name: 'WAEC Result Checker', subtitle: '1 PIN · 5 result checks', priceKobo: 400000)]),
    ProviderDef(id: 'neco', name: 'NECO', shortName: 'NECO', accent: 'green', inputLabel: 'Candidate name', inputPlaceholder: 'Enter candidate name', products: [Product(id: 'neco-token', name: 'NECO Result Token', subtitle: '1 secure result token', priceKobo: 150000)]),
    ProviderDef(id: 'jamb', name: 'JAMB', shortName: 'JAMB', accent: 'teal', inputLabel: 'Profile code', inputPlaceholder: 'Enter 10-digit profile code', products: [Product(id: 'jamb-epin', name: 'JAMB e-PIN', subtitle: 'Registration e-PIN', priceKobo: 470000)]),
    ProviderDef(id: 'nabteb', name: 'NABTEB', shortName: 'NABTEB', accent: 'orange', inputLabel: 'Candidate name', inputPlaceholder: 'Enter candidate name', products: [Product(id: 'nabteb-pin', name: 'NABTEB Result PIN', subtitle: '1 result checker PIN', priceKobo: 120000)]),
  ],
  ServiceKind.internet: const [
    ProviderDef(id: 'smile', name: 'Smile', shortName: 'Smile', accent: 'orange', inputLabel: 'Smile account or phone', inputPlaceholder: 'Enter account or phone number', products: [
      Product(id: 'smile-5gb', name: '5 GB', subtitle: '30 days · Anytime data', priceKobo: 500000),
      Product(id: 'smile-10gb', name: '10 GB', subtitle: '30 days · Anytime data', priceKobo: 850000, badge: 'Popular'),
    ]),
    ProviderDef(id: 'spectranet', name: 'Spectranet', shortName: 'Spectranet', accent: 'blue', inputLabel: 'Customer ID', inputPlaceholder: 'Enter Spectranet customer ID', products: [
      Product(id: 'spectranet-10gb', name: '10 GB', subtitle: '30 days · Unified value', priceKobo: 700000),
      Product(id: 'spectranet-25gb', name: '25 GB', subtitle: '30 days · Unified value', priceKobo: 1250000, badge: 'Best value'),
    ]),
    ProviderDef(id: 'ntel', name: 'ntel', shortName: 'ntel', accent: 'navy', inputLabel: 'ntel phone number', inputPlaceholder: 'Enter ntel number', products: [
      Product(id: 'ntel-5gb', name: '5 GB', subtitle: '30 days · Broadband data', priceKobo: 450000),
      Product(id: 'ntel-12gb', name: '12 GB', subtitle: '30 days · Broadband data', priceKobo: 900000, badge: 'Popular'),
    ]),
  ],
  ServiceKind.betting: const [
    ProviderDef(id: 'bet9ja', name: 'Bet9ja', shortName: 'Bet9ja', accent: 'green', inputLabel: 'Bet9ja user ID', inputPlaceholder: 'Enter your user ID'),
    ProviderDef(id: 'sportybet', name: 'SportyBet', shortName: 'SportyBet', accent: 'red', inputLabel: 'SportyBet user ID', inputPlaceholder: 'Enter your user ID'),
    ProviderDef(id: 'betking', name: 'BetKing', shortName: 'BetKing', accent: 'blue', inputLabel: 'BetKing user ID', inputPlaceholder: 'Enter your user ID'),
    ProviderDef(id: 'nairabet', name: 'NairaBET', shortName: 'NairaBET', accent: 'navy', inputLabel: 'NairaBET user ID', inputPlaceholder: 'Enter your user ID'),
  ],
};

const _discos = ['AEDC', 'IKEDC', 'EKEDC', 'IBEDC', 'KEDCO', 'EEDC', 'PHED', 'BEDC', 'JED', 'KAEDCO', 'YEDC'];

final Map<ServiceKind, List<int>> quickAmounts = {
  ServiceKind.airtime: [100, 200, 500, 1000, 2000, 5000],
  ServiceKind.electricity: [1000, 2000, 5000, 10000, 20000],
  ServiceKind.betting: [500, 1000, 2000, 5000, 10000],
};
