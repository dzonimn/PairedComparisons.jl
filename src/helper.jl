
#Helper functions for ratings RatingSystems - duplicating, getting games already played etc

function dupe_for_rating(games)
    #Takes dataframe of games and predictions, reverses the players, result and prediction and appends them to end#
    #Also adds handicap and var columns if not already there#

    dupe_backwards = rename(games, :P1 => :P2, :P2 => :P1, :P1_wins => :P2_wins, :P2_wins => :P1_wins)

    duplicated_games = vcat(games, dupe_backwards)

    if in("Handicap", names(games))
        dupe_backwards_handicap = - games.Handicap
        duplicated_games.Handicap = vcat(games.Handicap, dupe_backwards_handicap)
    else
        duplicated_games.Handicap = 0.0
    end

    if in("Var", names(games))
        dupe_backwards_var = games.Var
        duplicated_games.Var = vcat(games.Var, dupe_backwards_var)
    else
        duplicated_games.Var = 0.0
    end

    sort!(duplicated_games, :Period)

    return duplicated_games
end

function brier(predictions)
    #Brier score simple (versus all-wins)
    withoutmissing = filter(!isnan, collect(skipmissing(predictions)))
    return sum((1.0 .- withoutmissing).^2) / length(collect(skipmissing(predictions)))
end

function brier(predictions, true_scores)
    #Brier score with actual scores comparison
    return sum(collect(skipmissing(true_scores .- predictions).^2)) / length(collect(skipmissing(predictions)))
end

function brierss(predictions)
    #Brier skill score -- compares to unskilled = (1-0.5)^2 forecast.
    return 1 - (brier(predictions) / 0.25)
end

function cumcount(m)
    #Cumulative count occurrences
    d = Dict()
    function g(a)
        d[a] = get(d, a, 0) + 1
    end
    return g.(m)
end

function cumcount(m, surface)
    d = Dict()
    for i in 1:maximum(surface)
        d[i] = Dict()
    end

    function g(a, surface)
        d[surface][a] = get(d[surface], a, 0) + 1
    end

    return g.(m, surface)
end

function actual_scores(games)
    function score_safe(x, y)
        if x + y == 0
            return 0.5
        else
            return x / (x+y)
        end
    end
    return score_safe.(games.P1_wins, games.P2_wins)
end

function games_previously_played_count(training_games, testing_games)
    m = hcat(vcat(training_games.P1, testing_games.P2), vcat(training_games.P2, testing_games.P1))
    flattened = collect(Iterators.flatten(transpose(m)))
    counts = cumcount(flattened)
    return transpose(reshape(counts, 2, :))
end

function filter_today_played_before(training_games, today_names, threshold)
    #Filter predictions for day on threshold of games played in training set
    relevant = games_previously_played_count(training_games, today_names)[size(training_games)[1] + 1: size(training_games)[1] + size(today_names)[1],:]

    today_names.P1_before = relevant[:, 1]
    today_names.P2_before = relevant[:, 2]

    return filter(row -> row.P1_before >= threshold && row.P2_before >= threshold, today_names)
end

function filter_played_before(predictions, threshold, training_games, testing_games)
    played = games_previously_played_count(training_games, testing_games)
    playedf = minimum(played, dims = 2)
    matchlength = playedf[end - length(predictions) + 1: end]
    return predictions[matchlength .>= threshold]
end

function recent_players(games::DataFrame, recent_days::Int)
    #Return players who have had a game in the last few days
    latest_day = maximum(games.Day)
    games_played_recently = filter(row -> row.Day >= latest_day - recent_days, games)
    return unique(vcat(games_played_recently.P1, games_played_recently.P2))
end

function log_loss(predictions)
    withoutmissing = filter(!isnan, collect(skipmissing(predictions)))
    ll = -sum([log(prediction) for prediction in withoutmissing]) / length(withoutmissing)
    return ll
end

function log_loss(predictions, lower)
    tally = 0
    log_total = 0.0
    for row in 1:length(predictions[1])
        if (predictions[2][row] >= lower) & (predictions[3][row] >= lower) & (!ismissing(predictions[1][row])) & (!isnan(predictions[1][row]))
            tally += 1
            log_total += log(predictions[1][row])
        end
    end
    ll = - log_total / tally
    return ll, tally
end

function add_blanks(playerdayratings::Dict)
    days = collect(keys(sort(playerdayratings)))
    first_day = minimum(days)
    last_day = maximum(days)
    all_days = fill(NaN, last_day - first_day + 1)
    for j in days
        all_days[j - first_day + 1] = playerdayratings[j]
    end
    return all_days
end

function order_by_recency(games::DataFrame)
    P1 = vcat(games.P1)
    P2 = vcat(games.P2)
    return reverse(unique(transpose(hcat(P1, P2))))
end

function change_in_surface(training_games::DataFrame, testing_games::DataFrame, surface_training, surface_testing)
    m = hcat(vcat(training_games.P1, testing_games.P2), vcat(training_games.P2, testing_games.P1))
    flattened = collect(Iterators.flatten(transpose(m)))

    s = hcat(vcat(surface_training, surface_testing), vcat(surface_training, surface_testing))
    flattened_surface = collect(Iterators.flatten(transpose(s)))

    last_surface_played = transpose(reshape(last_surface(flattened, flattened_surface), 2, :)) 
    return .!isequal.(s, last_surface_played)
end

function last_surface(m, s)
    #Return the last surface and 
    d = Dict()
    function g(a, s)
        b = get(d, a, s)
        d[a] = s
        return b
    end
    return g.(m, s)
end


function jumble(predictions)
    #Run through and reverse half the games for ratings assessment
    l = length(predictions)
    true_scores = ones(Float64, l)
    jumbled_predictions = ones(Float64, l)
    
    for row in 1:l
        
        if isodd(row)
            jumbled_predictions[row] = 1.0 - predictions[row]
            true_scores[row] = 0.0
        else
            jumbled_predictions[row] = predictions[row]
            true_scores[row] = 1.0
        end
    end
    return jumbled_predictions, true_scores
end
