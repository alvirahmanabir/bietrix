/// Pagination-ready list wrapper (maps 1:1 to typical REST page responses).
class Paginated<T> {
  const Paginated({required this.items, required this.total, required this.page, required this.pageSize});
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  bool get hasMore => page * pageSize < total;
}
