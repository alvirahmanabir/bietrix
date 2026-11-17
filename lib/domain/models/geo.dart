/// Static Bangladesh division -> district lookup (swap for an API later).
abstract final class BdGeo {
  static const Map<String, List<String>> districts = {
    'Dhaka': ['Dhaka', 'Gazipur', 'Narayanganj', 'Tangail', 'Narsingdi'],
    'Chattogram': ['Chattogram', "Cox's Bazar", 'Comilla', 'Feni'],
    'Rajshahi': ['Rajshahi', 'Bogura', 'Pabna'],
    'Khulna': ['Khulna', 'Jashore', 'Bagerhat'],
    'Barishal': ['Barishal', 'Bhola', 'Patuakhali'],
    'Sylhet': ['Sylhet', 'Moulvibazar', 'Habiganj'],
    'Rangpur': ['Rangpur', 'Dinajpur', 'Bogra'],
    'Mymensingh': ['Mymensingh', 'Jamalpur', 'Netrokona'],
  };
  static List<String> get divisions => districts.keys.toList();
}
