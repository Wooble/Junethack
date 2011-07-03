require 'userscore'

# Limits by 10 any collection
def limit_by_10(collection)
    return collection.take(10) if collection.instance_of?(Array)
    collection.all(:limit => 10)
end

# This one returns last games ordered by endtime, with the latest game
# first.
# Optionally give conditions and limit.
def get_last_games(condition={}, limit=10)
    Game.all( {:order => [ :endtime.desc ], :limit => limit}.merge condition )
end

# This one returns users ordered by the number of ascensions they have
def most_ascensions_users(user=nil, limit=10)
    if user then
      repository.adapter.select "select count(1) as ascensions, (select name from users where id=user_id) as name from games where death='ascended' and user_id = ? group by user_id order by count(1) desc limit ?;", user, limit
    else
      repository.adapter.select "select count(1) as ascensions, (select name from users where id=user_id) as name from games where death='ascended' and user_id is not null group by user_id order by count(1) desc limit ?;", limit
    end
end

# Helper class for calculating ascension density
class AccountCalc
    attr_accessor :games, :score, :account, :game1, :game2
    def initialize
        @games = [ ]
        @score = 0
    end

    def num_ascensions
        ascensions = 0
        @games.each do |game|
            ascensions += 1 if game.death == 'ascended'
        end
        ascensions
    end

    def calculate_score_between(games, min_score = 0.0)
        final_max = 0.0
        max_so_far = max_ending_here = 0.0
        for asc in games do
            a = asc.death == 'ascended' ? 1.0 : -1.0
            max_ending_here = max_ending_here + a if max_ending_here + a > 0
            max_so_far = max_so_far > max_ending_here ? max_so_far : max_ending_here
        end
        final_max = final_max > max_so_far ? final_max : max_so_far
        final_max
    end

    def calculate_score
        # Calculate the longest distance between ascensions
        # So first ascension and last ascension

        @score = calculate_score_between(@games)
        @score
    end
end


def best_sustained_ascension_rate(and_collection=nil)
    # First step, collect the games.
    accounts = Account.all
    accounts_c = { }
    accounts.each do |account|
        accounts_c[account.name] = AccountCalc.new
        accounts_c[account.name].account = account
        accounts_c[account.name].games = Game.all(:name => account.name,
                                                  :order => [:endtime.desc])
    end

    # Sort the games and calculate score
    accounts_c.each do |account, account_class|
        account_class.calculate_score
    end

    users = { }
    # Wrap the thing up to users.
    accounts_c.each do |account, account_class|
        users[account_class.account.user.login] = { } if
            users[account_class.account.user.login].nil?
        u = users[account_class.account.user.login]
        if u[:score].nil? or u[:score] < account_class.score then
            u[:score] = account_class.score
            u[:game1] = account_class.game1
            u[:game2] = account_class.game2
        end
    end

    users.sort_by{|username, info| -info[:score]}
end

def best_sustained_ascension_rate(and_collection=nil)
    games = repository.adapter.select "select endtime, (select login from users where id = user_id) as user, death, name from games where user_id is not null order by user_id, endtime asc;"
    score = Hash.new(0)
    games.each {|g|
       d = g[:death]=='ascended' ? 1 : -1
       score[g[:user]] += d
       score[g[:user]] = 0 if score[g[:user]] < 0
    }
    score = score.delete_if {|key, value| value == 0 }
    score.sort_by{|user, score| -score}
end

def update_scores(game)
    return true if not game.user_id

    Scoreentry.transaction do
        t = TrophyScore.new
        if game.ascended
            Scoreentry.all(:variant => game.version,
                           :trophy  => "most_ascensions").destroy
            t.most_ascensions(game.version).each do |e|
                Scoreentry.create(:user_id => e.user_id,
                                  :variant => game.version,
                                  :value   => e.ascension.to_s,
                                  :endtime => e.endtime,
                                  :trophy  => "most_ascensions").save
            end

            Scoreentry.all(:variant => game.version,
                           :trophy  => "highest_scoring_ascension").destroy
            t.highest_scoring_ascension(game.version).each do |e|
                Scoreentry.create(:user_id => e.user_id,
                                  :variant => game.version,
                                  :value   => e.points.to_s,
                                  :endtime => e.endtime,
                                  :trophy  => "highest_scoring_ascension").save
            end

            Scoreentry.all(:variant => game.version,
                           :trophy  => "lowest_scoring_ascension").destroy
            t.lowest_scoring_ascension(game.version).each do |e|
                Scoreentry.create(:user_id => e.user_id,
                                  :variant => game.version,
                                  :value   => e.points.to_s,
                                  :endtime => e.endtime,
                                  :trophy  => "lowest_scoring_ascension").save
            end

            Scoreentry.all(:variant => game.version,
                           :trophy  => "most_conducts_ascension").destroy
            t.most_conducts_ascension(game.version).each do |e|
                Scoreentry.create(:user_id => e.user_id,
                                  :variant => game.version,
                                  :value   => e.nconducts.to_s,
                                  :endtime => e.endtime,
                                  :trophy  => "most_conducts_ascension").save
            end

            Scoreentry.all(:variant => game.version,
                           :trophy  => "fastest_ascension_realtime").destroy
            t.fastest_ascension_realtime(game.version).each do |e|
                Scoreentry.create(:user_id => e.user_id,
                                  :variant => game.version,
                                  :value   => e.duration.to_s,
                                  :endtime => e.endtime,
                                  :trophy  => "fastest_ascension_realtime").save
            end

            Scoreentry.all(:variant => game.version,
                           :trophy  => "fastest_ascension_gametime").destroy
            t.fastest_ascension_gametime(game.version).each do |e|
                Scoreentry.create(:user_id => e.user_id,
                                  :variant => game.version,
                                  :value   => e.duration.to_s,
                                  :endtime => e.endtime,
                                  :trophy  => "fastest_ascension_gametime").save
            end

            Scoreentry.all(:variant => game.version,
                           :trophy  => "longest_ascension_streaks").destroy
            t.longest_ascension_streaks(game.version).each do |e|
                Scoreentry.create(:user_id => e.user_id,
                                  :variant => game.version,
                                  :value   => e.streaks.to_s,
                                  :endtime => e.endtime,
                                  :trophy  => "longest_ascension_streaks").save
            end
        end
    end

    return true
end


