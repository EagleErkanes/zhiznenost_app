class QuoteModel {
  final String id;
  final String quoteText;
  final String author;
  final DateTime updatedAt;

  QuoteModel({
    required this.id,
    required this.quoteText,
    required this.author,
    required this.updatedAt,
  });

  factory QuoteModel.fromMap(Map<String, dynamic> map) {
    return QuoteModel(
      id: map['id'] ?? '',
      quoteText: map['quote_text'] ?? '',
      author: map['author'] ?? 'Треньор',
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}