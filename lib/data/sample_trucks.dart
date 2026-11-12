import '../models/truck.dart';

/// Sample tanker cards shipped with the app.
///
/// No backend yet: these stand in for the real driver directory. Prices are in
/// DZD per load.
const sampleTrucks = <Truck>[
  Truck(
    id: 't1',
    driverName: 'كريم بلقاسم',
    waterType: 'ماء صالح للشرب',
    volumeM3: 10,
    price: 4500,
    phone: '0550123456',
    city: 'الجزائر الوسطى',
  ),
  Truck(
    id: 't2',
    driverName: 'سفيان مرابط',
    waterType: 'ماء بئر (ري)',
    volumeM3: 20,
    price: 6000,
    phone: '0661234567',
    city: 'بئر مراد رايس',
  ),
  Truck(
    id: 't3',
    driverName: 'رشيد حمدي',
    waterType: 'ماء صالح للشرب',
    volumeM3: 5,
    price: 2800,
    phone: '0770345678',
    city: 'باب الوادي',
  ),
  Truck(
    id: 't4',
    driverName: 'يوسف بن عمر',
    waterType: 'ماء للبناء',
    volumeM3: 20,
    price: 5500,
    phone: '0555456789',
    city: 'الشراقة',
  ),
  Truck(
    id: 't5',
    driverName: 'عبد الرحمان زيدان',
    waterType: 'ماء بئر (ري)',
    volumeM3: 10,
    price: 3800,
    phone: '0668567890',
    city: 'الدرارية',
  ),
];
