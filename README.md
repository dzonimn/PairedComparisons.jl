# PairedComparisons

A Julia package implementing methods of rating entities ("players") based on win-loss comparisons between them ("games"). At present, the package contains implementations of:

- Elo (Arpad Elo's system: https://en.wikipedia.org/wiki/Elo_rating_system)
- Glicko (Mark Glickman's system: http://www.glicko.net/research/glicko.pdf)
- Bradley-Terry (Zermelo's system, badly named: https://en.wikipedia.org/wiki/Bradley%E2%80%93Terry_model)
- Whole History Rating (Remi Coulom's time-varying version of Bradley-Terry, https://www.remi-coulom.fr/WHR/WHR.pdf)

The package allows each algorithm to be fitted to sets of games and their results provided in a DataFrame format, and then to predict the results of future games whether those two players have met before or not.

For each algorithm, the package offers a struct (Elo, Glicko, BT, WHR) to record the current state, and the ratings assigned to each player.

## Usage

All the algorithms work on sets of games provided in DataFrames format, with columns as follows:

* P1 = A unique identifier for Player 1 - the package expects an integer
* P2 = Same for Player 2
* P1_wins = Number of games/points won by P1 on that day/match
* P2_wins = Number of games/points won by P2 on that day/match
* Period = Integer giving a time period in which the match-ups took place (e.g., the number of the day or week).

The order of the columns do not matter, so long as they have these names. You can also have other columns, which will be ignored.

(Note: if you omit the "Rating period" column, only two of the algorithms will work. Elo will go to a special "fast" version of the algorithm which treats each line as a separate time period and rates in the order given in the dataframe. Bradley-Terry does not care about the timing of the games, and will give the same results whatever the ordering).

So in the below, games1 is valid (rather boring) input for the Elo alogithm, but is invalid for the others. games2 is valid for all.

```
games1 = DataFrame(Player1 = [1], Player2 = [2], P1_wins = [1], P1_wins = [0])
games2 = copy(games1)
games2.Day = [1]
```


## Incremental and Global Algorithms

There are two separate approaches to paired comparisons in this package:

### Incremental algorithms

(Elo, Glicko)

Incremental algorithms iterate through the paired comparisons one by one, storing a very small amount of information for each player (one or two numbers) and updating this information with each matching. The archetypal example of this type is the Elo algorithm, which stores only one number for each entity (their latest Elo score), and updates it depending on the comparison results with other.

This package provides three main functions to work with incremental algorithms: fit! and predict.

Example to start using an incremental algorithm:
```
# Initialise a fresh Elo struct, with default values
elo = Elo()  

# Fit elo ratings given the games1 DataFrame (from above)
fit!(elo, games1) 

# Give a probability for player 1 to beat player 2
predict(elo, 1, 2) 
```
Glicko works exactly the same, but will need the DataFrame games2 as Glicko relies on ratings periods to work.

### Global algorithms

(Bradley-Terry, Whole History Rating)

Global algorithms take account of all paired comparisons in a single sweep, and typically optimise a rating for each entity (or series of time-varying ratings for each entity) in such a way that the fit is optimised. The information carried forward and is richer, typically relying on an object that encodes the entire history of every entity being rated. They tend to require iteration to convergence, and are generally more computationally intensive.

This package provides slightly different functions to work with global algorithms: add_games!, iterate!, predict
```
whr = WHR()  

# Add the game(s) from games2 to the Dict structure of players and games inside the Bradley-Terry object
add_games!(whr, games2) 

# Optimise the fit using a tailored algorithm (a Newton-Raphson method for WHR) to the games, with 10 iterations
iterate!(whr, 10)

# Give a probability for player 1 to beat player 2
predict(whr, 1, 2) 
```

## One-ahead testing

A convenience function is provided for each function to predict the results of each time period in advance of knowing the results, then fit the algorithm to that day, then iterate again. This is helpful when assessing the predictive performance of different algorithms. Typical usage looks like this:

```
elo = Elo()
fit!(elo, training_games)
one_ahead!(elo, testing_games, predict_algorithm = predict)
```
Output from one_ahead is a vector of probabilities for the games provided in the testing_games data frame, all predicted one time period ahead of the actual result, before the algorithm is updated with the actual results. The predict algorithm defaults to the standard form for each algorithm, but you can also substitute your own.
