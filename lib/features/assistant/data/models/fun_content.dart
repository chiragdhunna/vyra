enum FunType { quote, joke, fact }

/// A bite-sized bit of delight Vyra can fetch: an inspirational quote, a joke,
/// or a random fun fact.
class FunContent {
  final FunType type;
  final String text;
  final String? author;

  const FunContent({required this.type, required this.text, this.author});

  String get label => switch (type) {
        FunType.quote => 'Quote',
        FunType.joke => 'Joke',
        FunType.fact => 'Fun fact',
      };
}
