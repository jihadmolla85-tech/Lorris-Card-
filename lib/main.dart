
import 'package:flutter/material.dart' hide Card;
import 'loris.dart';

void main() => runApp(const LorisApp());

class LorisApp extends StatelessWidget {
  const LorisApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'LORIS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xff087f5b),
          brightness: Brightness.dark,
        ),
        home: const GameHome(),
      );
}

class GameHome extends StatefulWidget {
  const GameHome({super.key});

  @override
  State<GameHome> createState() => _GameHomeState();
}

class _GameHomeState extends State<GameHome> {
  PlayerCount playerCount = PlayerCount.four;
  late LorisMatchScore score;
  LorisRoundController? game;
  String status = 'নতুন ম্যাচ শুরু করুন';
  int humanSeat = 0;
  late Map<int, LorisTeam> selectedTeams;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    score = LorisMatchScore();
    selectedTeams = _defaultTeams(playerCount);
  }

  Map<int, LorisTeam> _defaultTeams(PlayerCount count) => {
        for (var i = 0; i < count.value; i++)
          i: i.isEven ? LorisTeam.teamOne : LorisTeam.teamTwo
      };

  Map<int, LorisTeam> get teams =>
      Map<int, LorisTeam>.from(selectedTeams);

  bool get teamsBalanced =>
      selectedTeams.values
          .where((t) => t == LorisTeam.teamOne)
          .length ==
      playerCount.value ~/ 2;

  String seatName(int seat) =>
      seat == humanSeat ? 'আপনি (P${seat + 1})' : 'AI ${seat + 1}';

  String teamName(LorisTeam team) =>
      team == LorisTeam.teamOne ? 'দল A' : 'দল B';

  String suitSymbol(Suit suit) => switch (suit) {
        Suit.clubs => '♣',
        Suit.diamonds => '♦',
        Suit.hearts => '♥',
        Suit.spades => '♠',
      };

  Color suitColor(Suit suit) =>
      suit == Suit.hearts || suit == Suit.diamonds
          ? Colors.redAccent
          : Colors.white;

  void newMatch() {
    setState(() {
      score = LorisMatchScore();
      game = LorisRoundController(
        playerCount: playerCount,
        teamBySeat: teams,
        dealerSeat: 0,
        matchScore: score,
      );
      status = 'ম্যাচ শুরু হয়েছে';
      game!.startRound();
    });

    _runAi();
  }

  void _refresh(String message) {
    if (!mounted) return;
    setState(() => status = message);
  }

  void _runAi() {
    if (game == null || busy) return;

    busy = true;

    try {
      var guard = 0;

      while (game != null && guard++ < 100) {
        final g = game!;

        if (g.phase == RoundPhase.bidding) {
          final seat = g.currentPlayerSeat!;

          if (seat == humanSeat) {
            _refresh('আপনার বিড দেওয়ার পালা');
            break;
          }

          final currentHigh = g.bidding!.submissions.values
              .whereType<int>()
              .fold<int>(0, (a, b) => a > b ? a : b);

          final hand = g.handFor(seat);

          final strength = hand
              .where((c) => c.isLoris || (c.rank ?? 0) >= 12)
              .length;

          int? bid;

          if (strength >= 5 && currentHigh < 7) {
            bid = currentHigh < 5 ? 5 : currentHigh + 1;
          } else if (strength >= 7 && currentHigh < 8) {
            bid = 8;
          }

          g.submitBid(seat: seat, bid: bid);

          if (g.phase == RoundPhase.trumpSelection) {
            if (g.winningBidderSeat == humanSeat) {
              _refresh('আপনার বিড জিতেছে—ট্রাম্প নির্বাচন করুন');
              break;
            }

            _aiChooseTrump();
          }

          continue;
        }

        if (g.phase == RoundPhase.trumpSelection) {
          if (g.winningBidderSeat == humanSeat) {
            _refresh('ট্রাম্প নির্বাচন করুন');
            break;
          }

          _aiChooseTrump();
          continue;
        }

        if (g.phase == RoundPhase.playing) {
          final seat = g.currentPlayerSeat!;

          if (seat == humanSeat) {
            _refresh('আপনার কার্ড চালার পালা');
            break;
          }

          final legal = g.handFor(seat)
              .where((c) => g.isLegalCard(seat, c))
              .toList();

          if (legal.isEmpty) {
            _refresh('কার্ড নির্বাচনে সমস্যা হয়েছে');
            break;
          }

          // সংশোধিত comparator
          legal.sort(
            (a, b) =>
                _cardValue(a).compareTo(_cardValue(b)),
          );

          final chosen = legal.first;

          g.playCard(seat: seat, card: chosen);

          if (g.currentTrick.isEmpty &&
              g.phase == RoundPhase.playing) {
            _refresh(
              'ট্রিক সম্পন্ন—${seatName(g.trickLeaderSeat!)} পরের চাল দেবে',
            );
          }

          continue;
        }

        if (g.phase == RoundPhase.roundComplete) {
          _refresh('রাউন্ড শেষ—পরের রাউন্ড শুরু করুন');
          break;
        }

        if (g.phase == RoundPhase.matchComplete) {
          _refresh(
            'ম্যাচ শেষ! ${g.matchScore.winner == LorisMatchWinner.teamOne ? 'দল A' : 'দল B'} জিতেছে',
          );
          break;
        }

        break;
      }
    } finally {
      busy = false;
      if (mounted) setState(() {});
    }
  }

  int _cardValue(Card c) =>
      c.isLoris ? 100 : (c.rank ?? 0) +
          (c.suit == game?.trumpSuit ? 20 : 0);

  void _aiChooseTrump() {
    final g = game!;
    final seat = g.winningBidderSeat!;

    final counts = {
      for (final s in Suit.values)
        s: g.handFor(seat)
            .where((c) => !c.isLoris && c.suit == s)
            .length
    };

    final suit = counts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    g.declareTrump(seat: seat, suit: suit);
  }

  void bid(int? value) {
    final g = game!;
    g.submitBid(seat: humanSeat, bid: value);
    _runAi();
  }

  void chooseTrump(Suit suit) {
    game!.declareTrump(seat: humanSeat, suit: suit);
    _runAi();
  }

  void play(Card card) {
    final g = game!;

    if (!g.isLegalCard(humanSeat, card)) return;

    g.playCard(seat: humanSeat, card: card);
    _runAi();
  }

  String cardText(Card c) =>
      c.isLoris ? '★\nLORIS' : '${suitSymbol(c.suit)}\n${c.displayName}';

  @override
  Widget build(BuildContext context) {
    final g = game;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LORIS',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: g == null ? _startScreen() : _gameScreen(g),
      ),
    );
  }

  Widget _startScreen() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.style,
                size: 86,
                color: Color(0xff65d6a6),
              ),
              const SizedBox(height: 18),
              const Text(
                'LORIS CARD GAME',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'অফলাইন মোড • AI প্রতিপক্ষ',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 30),
              const Text('খেলোয়াড় নির্বাচন করুন'),
              const SizedBox(height: 8),
              SegmentedButton<PlayerCount>(
                segments: const [
                  ButtonSegment(
                    value: PlayerCount.four,
                    label: Text('৪ জন'),
                  ),
                  ButtonSegment(
                    value: PlayerCount.six,
                    label: Text('৬ জন'),
                  ),
                ],
                selected: {playerCount},
                onSelectionChanged: (v) => setState(() {
                  playerCount = v.first;
                  selectedTeams = _defaultTeams(playerCount);
                  humanSeat = 0;
                }),
              ),
              const SizedBox(height: 18),
              const Text('দল ও আপনার আসন নির্বাচন করুন'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < playerCount.value; i++)
                    ChoiceChip(
                      label: Text(
                        'P${i + 1}: ${selectedTeams[i] == LorisTeam.teamOne ? 'দল A' : 'দল B'}',
                      ),
                      selected:
                          selectedTeams[i] == LorisTeam.teamOne,
                      onSelected: (_) => setState(() {
                        selectedTeams[i] =
                            selectedTeams[i] == LorisTeam.teamOne
                                ? LorisTeam.teamTwo
                                : LorisTeam.teamOne;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButton<int>(
                value: humanSeat,
                dropdownColor: const Color(0xff263238),
                items: [
                  for (var i = 0; i < playerCount.value; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text('আপনার আসন: P${i + 1}'),
                    ),
                ],
                onChanged: (v) =>
                    setState(() => humanSeat = v ?? 0),
              ),
              Text(
                teamsBalanced
                    ? 'দুই দলে সমান খেলোয়াড় আছে'
                    : 'দুই দলে সমান খেলোয়াড় রাখুন',
                style: TextStyle(
                  color: teamsBalanced
                      ? Colors.greenAccent
                      : Colors.orangeAccent,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: teamsBalanced ? newMatch : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('নতুন ম্যাচ শুরু করুন'),
              ),
              const SizedBox(height: 16),
              const Text(
                'এই সংস্করণে একই ফোনে আপনি বনাম AI খেলবেন।',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );

  Widget _gameScreen(LorisRoundController g) {
    final hand = g.handFor(humanSeat);

    final highest = g.bidding!.submissions.values
        .whereType<int>()
        .fold<int>(0, (a, b) => a > b ? a : b);

    return Column(
      children: [
        _scoreBar(g),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            status,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(child: _table(g)),
        if (g.phase == RoundPhase.bidding &&
            g.currentPlayerSeat == humanSeat)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => bid(null),
                  child: const Text('পাস'),
                ),
                for (var n =
                        (highest + 1 < 5 ? 5 : highest + 1);
                    n <= 8;
                    n++)
                  FilledButton(
                    onPressed: () => bid(n),
                    child: Text('$n কল'),
                  ),
              ],
            ),
          ),
        if (g.phase == RoundPhase.trumpSelection &&
            g.winningBidderSeat == humanSeat)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final s in Suit.values)
                  FilledButton(
                    onPressed: () => chooseTrump(s),
                    child: Text(suitSymbol(s)),
                  ),
              ],
            ),
          ),
        if (g.phase == RoundPhase.playing &&
            g.currentPlayerSeat == humanSeat)
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: hand.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 5),
              itemBuilder: (context, i) {
                final c = hand[i];
                final legal = g.isLegalCard(humanSeat, c);

                return InkWell(
                  onTap: legal ? () => play(c) : null,
                  child: Opacity(
                    opacity: legal ? 1 : .38,
                    child: Container(
                      width: 64,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: legal ? Colors.amber : Colors.grey,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          cardText(c),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: c.isLoris
                                ? Colors.deepPurple
                                : suitColor(c.suit),
                            fontWeight: FontWeight.bold,
                            fontSize: c.isLoris ? 13 : 21,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (g.phase == RoundPhase.roundComplete)
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(
              onPressed: () {
                setState(() {
                  g.startRound();
                  status = 'নতুন রাউন্ড';
                });
                _runAi();
              },
              child: const Text('পরের রাউন্ড'),
            ),
          ),
        if (g.phase == RoundPhase.matchComplete)
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(
              onPressed: () => setState(() => game = null),
              child: const Text('মেনুতে ফিরুন'),
            ),
          ),
      ],
    );
  }

  Widget _scoreBar(LorisRoundController g) => Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: _scoreTile(
                'দল A',
                score.teamOneScore,
                g.teamOneTricks,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _scoreTile(
                'দল B',
                score.teamTwoScore,
                g.teamTwoTricks,
              ),
            ),
          ],
        ),
      );

  Widget _scoreTile(String name, int points, int tricks) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(name),
            Text(
              '$points',
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'এই রাউন্ডে $tricks ট্রিক',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );

  Widget _table(LorisRoundController g) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xff07583f),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: Column(
          children: [
            Text(
              'ডিলার: ${seatName(g.dealerSeat)}   •   ট্রাম্প: ${g.trumpSuit == null ? 'নির্ধারিত নয়' : suitSymbol(g.trumpSuit!)}',
              style: const TextStyle(color: Colors.white70),
            ),
            const Spacer(),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                for (var seat = 0; seat < playerCount.value; seat++)
                  Container(
                    width: 88,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: g.currentPlayerSeat == seat
                          ? Colors.amber.shade800
                          : Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          seatName(seat),
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text('${g.handFor(seat).length} কার্ড'),
                        if (g.trickLeaderSeat == seat)
                          const Text(
                            'লিডার',
                            style: TextStyle(fontSize: 10),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'চলতি ট্রিক',
              style: TextStyle(color: Colors.white70),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                for (final p in g.currentTrick)
                  Container(
                    width: 54,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        cardText(p.card),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: p.card.isLoris
                              ? Colors.deepPurple
                              : suitColor(p.card.suit),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              'বিড: ${g.contractBid?.toString() ?? 'চলছে'}   •   জেতা ট্রিক: ${g.completedTricks.length}/8',
            ),
          ],
        ),
      );
}
