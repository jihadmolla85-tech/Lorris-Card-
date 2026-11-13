
import 'package:flutter/material.dart' hide Card;

import 'loris.dart';
import 'src/loris_card.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LorisApp());
}

class LorisApp extends StatelessWidget {
  const LorisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LORIS',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff10251e),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff087a52),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const GameHome(),
    );
  }
}

class GameHome extends StatefulWidget {
  const GameHome({super.key});

  @override
  State<GameHome> createState() => _GameHomeState();
}

class _GameHomeState extends State<GameHome> {
  PlayerCount playerCount = PlayerCount.four;

  Map<int, LorisTeam> selectedTeams = {};

  int humanSeat = 0;

  LorisRoundController? game;

  bool busy = false;

  String status = 'নতুন ম্যাচ শুরু করুন';

  @override
  void initState() {
    super.initState();
    selectedTeams = _defaultTeams(playerCount);
  }

  Map<int, LorisTeam> _defaultTeams(PlayerCount count) {
    return {
      for (var i = 0; i < count.value; i++)
        i: i.isEven
            ? LorisTeam.teamOne
            : LorisTeam.teamTwo,
    };
  }

  bool get teamsBalanced {
    final one = selectedTeams.values
        .where((t) => t == LorisTeam.teamOne)
        .length;

    final two = selectedTeams.values
        .where((t) => t == LorisTeam.teamTwo)
        .length;

    return one == playerCount.value ~/ 2 &&
        two == playerCount.value ~/ 2;
  }

  void _refresh(String message) {
    if (!mounted) return;

    setState(() {
      status = message;
    });
  }

  void newMatch() {
    if (!teamsBalanced) return;

    final score = LorisMatchScore();

    final newGame = LorisRoundController(
      playerCount: playerCount,
      teamBySeat: Map<int, LorisTeam>.from(selectedTeams),
      dealerSeat: 0,
      matchScore: score,
    );

    newGame.startRound();

    setState(() {
      game = newGame;
      status = 'নতুন রাউন্ড শুরু হয়েছে';
    });

    _runAi();
  }

  String seatName(int seat) {
    if (seat == humanSeat) return 'আপনি';
    return 'AI ${seat + 1}';
  }

  String suitSymbol(Suit suit) {
    switch (suit) {
      case Suit.clubs:
        return '♣';
      case Suit.diamonds:
        return '♦';
      case Suit.hearts:
        return '♥';
      case Suit.spades:
        return '♠';
    }
  }

  Color suitColor(Suit suit) {
    if (suit == Suit.hearts || suit == Suit.diamonds) {
      return Colors.red;
    }
    return Colors.black;
  }

  String cardText(Card card) {
    if (card.isLoris) return '★\nLORIS';

    return '${suitSymbol(card.suit)}\n${card.displayName}';
  }

  int _cardValue(Card card) {
    if (card.isLoris) return 100;

    return (card.rank ?? 0) +
        (card.suit == game?.trumpSuit ? 20 : 0);
  }

  int? _chooseAiBid(int seat, int highestBid) {
    final hand = game!.handFor(seat);

    final lorisCount =
        hand.where((c) => c.isLoris).length;

    final highCards = hand.where(
      (c) => !c.isLoris && (c.rank ?? 0) >= 11,
    ).length;

    final suitCounts = <Suit, int>{
      for (final suit in Suit.values)
        suit: hand
            .where((c) => !c.isLoris && c.suit == suit)
            .length,
    };

    final longestSuit = suitCounts.values.reduce(
      (a, b) => a > b ? a : b,
    );

    final strength =
        lorisCount * 2 + highCards + longestSuit ~/ 2;

    int? bidValue;

    if (strength >= 8) {
      bidValue = 8;
    } else if (strength >= 6) {
      bidValue = 7;
    } else if (strength >= 5) {
      bidValue = 6;
    } else if (strength >= 4) {
      bidValue = 5;
    }

    if (bidValue != null && bidValue <= highestBid) {
      return null;
    }

    return bidValue;
  }

  void _runAi() {
    if (busy || game == null || !mounted) return;

    busy = true;

    try {
      var safetyCounter = 0;

      while (safetyCounter < 100) {
        safetyCounter++;

        final g = game!;

        if (g.phase == RoundPhase.bidding) {
          final seat = g.currentPlayerSeat;

          if (seat == null) break;

          if (seat == humanSeat) {
            _refresh('আপনার বিড দেওয়ার পালা');
            break;
          }

          final highest = g.bidding!.submissions.values
              .whereType<int>()
              .fold<int>(0, (a, b) => a > b ? a : b);

          final aiBid = _chooseAiBid(seat, highest);

          g.submitBid(seat: seat, bid: aiBid);

          if (g.phase == RoundPhase.trumpSelection) {
            if (g.winningBidderSeat == humanSeat) {
              _refresh('আপনার বিড জিতেছে। ট্রাম্প নির্বাচন করুন');
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
          final seat = g.currentPlayerSeat;

          if (seat == null) break;

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

          legal.sort(
            (a, b) => _cardValue(a).compareTo(_cardValue(b)),
          );

          final chosen = legal.first;

          g.playCard(seat: seat, card: chosen);

          if (g.phase == RoundPhase.roundComplete) {
            _refresh('রাউন্ড শেষ হয়েছে');
            break;
          }

          continue;
        }

        if (g.phase == RoundPhase.roundComplete) {
          _refresh('রাউন্ড শেষ। পরের রাউন্ড শুরু করুন');
          break;
        }

        if (g.phase == RoundPhase.matchComplete) {
          final winner = g.matchScore.winner;

          _refresh(
            'ম্যাচ শেষ! ${winner == LorisMatchWinner.teamOne ? 'দল A' : 'দল B'} জিতেছে',
          );
          break;
        }

        break;
      }
    } finally {
      busy = false;

      if (mounted) {
        setState(() {});
      }
    }
  }

  void _aiChooseTrump() {
    final g = game;

    if (g == null || g.winningBidderSeat == null) return;

    final seat = g.winningBidderSeat!;

    final counts = {
      for (final suit in Suit.values)
        suit: g.handFor(seat)
            .where((c) => !c.isLoris && c.suit == suit)
            .length,
    };

    final suit = counts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    g.declareTrump(seat: seat, suit: suit);
  }

  void bid(int? value) {
    final g = game;

    if (g == null || busy) return;

    g.submitBid(
      seat: humanSeat,
      bid: value,
    );

    setState(() {
      status = value == null
          ? 'আপনি পাস করেছেন'
          : 'আপনার বিড: $value';
    });

    _runAi();
  }

  void chooseTrump(Suit suit) {
    final g = game;

    if (g == null || busy) return;

    g.declareTrump(
      seat: humanSeat,
      suit: suit,
    );

    setState(() {
      status = 'ট্রাম্প নির্বাচন করা হয়েছে';
    });

    _runAi();
  }

  void play(Card card) {
    final g = game;

    if (g == null || busy) return;

    if (!g.isLegalCard(humanSeat, card)) return;

    g.playCard(
      seat: humanSeat,
      card: card,
    );

    setState(() {
      status = 'আপনি ${card.displayName} চাল দিয়েছেন';
    });

    _runAi();
  }

  void startNextRound() {
    final g = game;

    if (g == null) return;

    setState(() {
      g.startRound();
      status = 'নতুন রাউন্ড শুরু হয়েছে';
    });

    _runAi();
  }

  void returnToMenu() {
    setState(() {
      game = null;
      status = 'নতুন ম্যাচ শুরু করুন';
    });
  }

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
        actions: [
          IconButton(
            tooltip: 'মেনু',
            icon: const Icon(Icons.home),
            onPressed: returnToMenu,
          ),
        ],
      ),
      body: SafeArea(
        child: g == null
            ? _startScreen()
            : _gameScreen(g),
      ),
    );
  }

  Widget _startScreen() {
    return Center(
      child: SingleChildScrollView(
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
              onSelectionChanged: (v) {
                setState(() {
                  playerCount = v.first;
                  selectedTeams = _defaultTeams(playerCount);
                  humanSeat = 0;
                });
              },
            ),

            const SizedBox(height: 18),

            const Text('দল নির্বাচন করুন'),

            const SizedBox(height: 8),

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
                    onSelected: (_) {
                      setState(() {
                        selectedTeams[i] =
                            selectedTeams[i] == LorisTeam.teamOne
                                ? LorisTeam.teamTwo
                                : LorisTeam.teamOne;
                      });
                    },
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
              onChanged: (v) {
                setState(() {
                  humanSeat = v ?? 0;
                });
              },
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
  }

  Widget _gameScreen(LorisRoundController g) {
    final hand = g.handFor(humanSeat);

    final highest = g.bidding!.submissions.values
        .whereType<int>()
        .fold<int>(0, (a, b) => a > b ? a : b);

    return Column(
      children: [
        _scoreBar(g),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(
            status,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        Expanded(
          child: _table(g),
        ),

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
                  onPressed: busy ? null : () => bid(null),
                  child: const Text('পাস'),
                ),

                for (
                  var n = highest + 1 < 5 ? 5 : highest + 1;
                  n <= 8;
                  n++
                )
                  FilledButton(
                    onPressed: busy ? null : () => bid(n),
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
                for (final suit in Suit.values)
                  FilledButton(
                    onPressed: busy ? null : () => chooseTrump(suit),
                    child: Text(
                      suitSymbol(suit),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
              ],
            ),
          ),

        if (g.phase == RoundPhase.playing &&
            g.currentPlayerSeat == humanSeat)
          SizedBox(
            height: 135,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: hand.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 5),
              itemBuilder: (context, i) {
                final card = hand[i];

                final legal =
                    g.isLegalCard(humanSeat, card);

                return InkWell(
                  onTap: legal && !busy
                      ? () => play(card)
                      : null,
                  child: Opacity(
                    opacity: legal ? 1 : .38,
                    child: Container(
                      width: 64,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: legal
                              ? Colors.amber
                              : Colors.grey,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          cardText(card),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: card.isLoris
                                ? Colors.deepPurple
                                : suitColor(card.suit),
                            fontWeight: FontWeight.bold,
                            fontSize: card.isLoris ? 13 : 21,
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
              onPressed: startNextRound,
              child: const Text('পরের রাউন্ড'),
            ),
          ),

        if (g.phase == RoundPhase.matchComplete)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  '${g.matchScore.winner == LorisMatchWinner.teamOne ? 'দল A' : 'দল B'} ম্যাচ জিতেছে!',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: returnToMenu,
                  child: const Text('মেনুতে ফিরুন'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _scoreBar(LorisRoundController g) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: _scoreTile(
              'দল A',
              g.matchScore.teamOneScore,
              g.teamOneTricks,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _scoreTile(
              'দল B',
              g.matchScore.teamTwoScore,
              g.teamTwoTricks,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreTile(String name, int points, int tricks) {
    return Container(
      padding: const EdgeInsets.all(8),
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
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'এই রাউন্ডে $tricks ট্রিক',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _table(LorisRoundController g) {
    final count = playerCount.value;

    final positions = count == 4
        ? [
            Alignment.bottomCenter,
            Alignment.centerLeft,
            Alignment.topCenter,
            Alignment.centerRight,
          ]
        : [
            Alignment.bottomCenter,
            Alignment.bottomLeft,
            Alignment.topLeft,
            Alignment.topCenter,
            Alignment.topRight,
            Alignment.bottomRight,
          ];

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xff07583f),
        borderRadius: BorderRadius.circular(90),
        border: Border.all(
          color: const Color(0xffc5a45b),
          width: 4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(7),
            child: Text(
              'ডিলার: ${seatName(g.dealerSeat)}'
              '  •  ট্রাম্প: ${g.trumpSuit == null ? 'নির্ধারিত নয়' : suitSymbol(g.trumpSuit!)}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ),

          Expanded(
            child: Stack(
              children: [
                for (var i = 0; i < count; i++)
                  Align(
                    alignment:
                        positions[(i - humanSeat + count) % count],
                    child: _playerAvatar(g, i),
                  ),

                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'চলতি ট্রিক',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 5,
                        children: [
                          for (final played in g.currentTrick)
                            _smallCard(played.card),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(7),
            child: Text(
              'বিড: ${g.contractBid?.toString() ?? 'চলছে'}'
              '  •  জেতা ট্রিক: ${g.completedTricks.length}/8',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallCard(Card card) {
    return Container(
      width: 43,
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.amber),
      ),
      child: Center(
        child: Text(
          cardText(card),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: card.isLoris
                ? Colors.deepPurple
                : suitColor(card.suit),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _playerAvatar(LorisRoundController g, int seat) {
    final active = g.currentPlayerSeat == seat;
    final isHuman = seat == humanSeat;

    return Container(
      width: 76,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: active
            ? Colors.amber.shade800
            : Colors.black45,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: active ? Colors.yellow : Colors.white30,
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            child: Icon(
              isHuman ? Icons.person : Icons.smart_toy,
              color: Colors.green.shade900,
              size: 21,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            seatName(seat),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),

          Text(
            '${g.handFor(seat).length} কার্ড',
            style: const TextStyle(fontSize: 9),
          ),

          if (g.trickLeaderSeat == seat)
            const Text(
              'লিডার',
              style: TextStyle(
                fontSize: 9,
                color: Colors.yellow,
              ),
            ),
        ],
      ),
    );
  }
}
