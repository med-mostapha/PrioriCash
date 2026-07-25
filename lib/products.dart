class Product {
  const Product({required this.name, required this.price});
  final String name;
  final double price;
}

List<Product> products = [
  const Product(name: "Laptop", price: 1399),
  const Product(name: "Car", price: 13050),
  const Product(name: "House", price: 3400500),
];

enum SortType { name, price }
