/*=============================================
			C	A	S	A	S
===============================================*/

-- 1. For each driver, looking at their laps in order, show what their lap time was on the lap immediately before the current one — this helps spot a sudden pace drop, possibly from traffic or a mistake.
SELECT
    driver_id,
    race_id,
    lap_number,
    lap_time_seconds,
    LAG(lap_time_seconds) OVER (
        PARTITION BY driver_id
        ORDER BY race_id, lap_number
    ) AS previous_lap_time
FROM LapTimes;

-- 2. The strategy team wants something they can plug straight into their live timing tool that always reflects each team's current total pit stop count, without re-deriving it manually each session.
CREATE VIEW TeamPitStops AS
SELECT
    t.team_id,
    t.team_name,
    SUM(pit_stop) AS total_pit_stops
FROM Teams t
JOIN Drivers d
ON t.team_id = d.team_id
JOIN LapTimes lt
ON d.driver_id = lt.driver_id
GROUP BY t.team_id, t.team_name;

-- 3. Identify any driver who has never completed a single lap this season — a serious performance concern to flag to the team.
SELECT
    d.driver_id,
    d.driver_name
FROM Drivers d
LEFT JOIN LapTimes lt
ON d.driver_id = lt.driver_id
WHERE lt.driver_id IS NULL;


-- 4. Count the laps completed by each driver this season, and shortlist only the drivers with fewer than 100 total laps recorded — they may have suffered reliability issues.
SELECT
    d.driver_id,
    d.driver_name,
    COUNT(lt.lap_id) AS total_laps
FROM Drivers d
LEFT JOIN LapTimes lt
ON d.driver_id = lt.driver_id
GROUP BY d.driver_id, d.driver_name
HAVING COUNT(lt.lap_id) < 100;

-- 5. Going forward, the league wants to record each driver's contract expiry date. Adjust the driver records so this detail can be captured.
ALTER TABLE Drivers
ADD contract_expiry DATE;

-- 6. Group all lap times by circuit, and flag circuits where the average lap time is unusually high — this may point to a particularly technical or slow layout.
SELECT
    c.circuit_name,
    AVG(lt.lap_time_seconds) AS average_lap_time
FROM Circuits c
JOIN Races r
ON c.circuit_id = r.circuit_id
JOIN LapTimes lt
ON r.race_id = lt.race_id
GROUP BY c.circuit_name
HAVING AVG(lt.lap_time_seconds) > 95;

-- 7. Prepare a results sheet listing every lap along with the driver's name and the team they race for, all on a single line per lap.
SELECT
    lt.lap_id,
    d.driver_name,
    t.team_name,
    lt.lap_number,
    lt.lap_time_seconds
FROM LapTimes lt
JOIN Drivers d
ON lt.driver_id = d.driver_id
JOIN Teams t
ON d.team_id = t.team_id;

-- 8. The broadcast team wants to know, in one number, how many pit stops have been logged across the entire season.
SELECT
    SUM(pit_stop) AS total_pit_stops
FROM LapTimes;

-- 9. Build an intermediate circuit-by-circuit average lap time, then use it to flag every circuit where laps are running noticeably slower than the season-wide average.
WITH CircuitAverage AS
(
    SELECT
        c.circuit_id,
        c.circuit_name,
        AVG(lt.lap_time_seconds) AS average_lap
    FROM Circuits c
    JOIN Races r
    ON c.circuit_id = r.circuit_id
    JOIN LapTimes lt
    ON r.race_id = lt.race_id
    GROUP BY c.circuit_id, c.circuit_name
)

SELECT *
FROM CircuitAverage
WHERE average_lap >
(
    SELECT AVG(lap_time_seconds)
    FROM LapTimes
);

-- 10. For each driver, show what their very next lap time will be, placed right alongside the current one, to help spot a pattern building up across consecutive laps.
SELECT
    driver_id,
    race_id,
    lap_number,
    lap_time_seconds,
    LEAD(lap_time_seconds) OVER (
        PARTITION BY driver_id
        ORDER BY race_id, lap_number
    ) AS next_lap_time
FROM LapTimes;

-- 11. List every driver along with their most recent lap time, making sure drivers who haven't completed a single lap this weekend still appear on the list rather than disappearing.
WITH LatestLap AS
(
    SELECT
        driver_id,
        lap_time_seconds,
        ROW_NUMBER() OVER (
            PARTITION BY driver_id
            ORDER BY race_id DESC, lap_number DESC
        ) AS rn
    FROM LapTimes
)

SELECT
    d.driver_name,
    ll.lap_time_seconds
FROM Drivers d
LEFT JOIN LatestLap ll
ON d.driver_id = ll.driver_id
AND ll.rn = 1;

-- 12. Engineers constantly search lap records using a specific driver's ID to pull up their full season history instantly, but this lookup has started to feel sluggish now that the lap table has grown into the tens of thousands. What would you do about it?
CREATE INDEX idx_driver_id
ON LapTimes(driver_id);

-- 13. A batch of very old test-session lap times from a discontinued practice format is cluttering the database and is no longer needed for any analysis. Remove exactly those records.
DELETE FROM LapTimes
WHERE season_year = 'Test';

-- 14. Work out how many distinct circuits the championship has raced at so far.
SELECT
    COUNT(DISTINCT circuit_id) AS total_circuits
FROM Races;

-- 15. Label each lap as 'Fast' (under 85 seconds), 'Average' (85-95 seconds), or 'Slow' (above 95 seconds), so the strategy team can spot pace trends at a glance.
SELECT
    lap_id,
    lap_time_seconds,
    CASE
        WHEN lap_time_seconds < 85 THEN 'Fast'
        WHEN lap_time_seconds BETWEEN 85 AND 95 THEN 'Average'
        ELSE 'Slow'
    END AS pace
FROM LapTimes;

-- 16. Across the entire season, order every lap by lap time to surface the fastest laps of the year, making sure that if two laps share the exact same time, neither one gets unfairly skipped in the ordering.
select
    lap_id,
    driver_id,
    lap_time_seconds,
    dense_rank() over(order by lap_time_seconds) as lap_rank
from laptimes;

-- 17. A timing system recalibration means every lap time recorded at one specific circuit needs to be corrected by a fixed offset. Apply this correction to just that circuit's laps.
update laptimes
set lap_time_seconds = lap_time_seconds + 0.5
where race_id in (
    select race_id
    from races
    where circuit_id = 3
);

-- 18. Track down which circuit hosted the race with the single fastest average lap time recorded anywhere this season.
select
    c.circuit_name,
    avg(lt.lap_time_seconds) as avg_lap_time
from circuits c
join races r
on c.circuit_id = r.circuit_id
join laptimes lt
on r.race_id = lt.race_id
group by c.circuit_name
order by avg_lap_time
limit 1;

-- 19. The scheduling team wants to know which day of the week races are most commonly held on, to help plan next year's calendar.
select
    dayname(race_date) as race_day,
    count(*) as total_races
from races
group by race_day
order by total_races desc
limit 1;

-- 20. Cross-check circuits against the race calendar to identify any circuit that hasn't been used in the current season at all.
select
    circuit_name
from circuits
where circuit_id not in
(
    select distinct circuit_id
    from races
    where season_year = year(curdate())
);
-- 21. Identify all races that took place more than two years ago, since historical data beyond this point is being moved to a separate archive.
select *
from races
where race_date < date_sub(curdate(), interval 2 year);

-- 22. A data-entry mistake caused an entire race's laps to be logged under the wrong circuit altogether. Correct this in one sweep rather than lap by lap.
update races
set circuit_id = 5
where race_id = 12;

-- 23. The marketing team wants to flag any circuit name that's unusually long (more than 25 characters) so it can be shortened for the mobile app.
select
    circuit_name
from circuits
where length(circuit_name) > 25;

-- 24. A freelance analyst's contract for the season has just ended, and their access to the database needs to be fully withdrawn with immediate effect.
REVOKE ALL PRIVILEGES, GRANT OPTION
FROM 'analyst'@'localhost';

-- 25. An engineer tries to save a new driver record without assigning them to a team. What should prevent that incomplete record from being saved?
alter table drivers
modify team_id int not null;

-- 26. A new lap record arrives for a race that was never added to the calendar. Explain what should happen to this record and why it must not be allowed to slip through.
alter table laptimes
add constraint fk_race
foreign key (race_id)
references races(race_id);

-- 27. A driver who was thought to be out for the season due to injury has just been confirmed to return for the next race. Update their team assignment to reflect a new team signing.
update drivers
set team_id = 4
where driver_id = 7;

-- 28. Work this out in two stages: first tally up each driver's total number of laps this season, then use that to shortlist drivers who've completed fewer than 200 laps — these may have missed races.
with driverlaps as
(
    select
        driver_id,
        count(*) as total_laps
    from laptimes
    group by driver_id
)

select
    d.driver_name,
    dl.total_laps
from drivers d
join driverlaps dl
on d.driver_id = dl.driver_id
where dl.total_laps < 200;

-- 29. Sort each team's founding year into 'Veteran' (before 2000), 'Established' (2000-2012), or 'New Entrant' (after 2012), to help commentators frame the grid's history on air.
select
    team_name,
    founded_year,
    case
        when founded_year < 2000 then 'veteran'
        when founded_year between 2000 and 2012 then 'established'
        else 'new entrant'
    end as category
from teams;

-- 30. Within each race, order the drivers by their lap times, fastest first, to reconstruct the effective running order for that lap.
select
    race_id,
    driver_id,
    lap_time_seconds,
    rank() over(
        partition by race_id
        order by lap_time_seconds
    ) as race_rank
from laptimes;

-- 31. For the technical review, work out the average lap time recorded at each individual circuit.
select
    c.circuit_name,
    avg(lt.lap_time_seconds) as average_lap_time
from circuits c
join races r
on c.circuit_id = r.circuit_id
join laptimes lt
on r.race_id = lt.race_id
group by c.circuit_name;

-- 32. After a few seasons and some team changes, nobody quite remembers what was set up to speed up lookups on the lap times table. Check what's currently in place.
show index from laptimes;

-- 33. For a driver under investigation for a scheduling dispute, work out how many days passed between their first race of the season and their most recent one.
select
    d.driver_name,
    datediff(max(r.race_date), min(r.race_date)) as total_days
from drivers d
join laptimes lt
on d.driver_id = lt.driver_id
join races r
on lt.race_id = r.race_id
group by d.driver_name;

-- 34. Calculate the average number of championships won per team, to see how competitive the grid has historically been.
select
    avg(championships_won) as average_championships
from teams;

-- 35. Identify every driver who belongs to whichever single team currently has the most championships won.

select
    d.driver_name,
    t.team_name
from drivers d
join teams t
on d.team_id = t.team_id
where t.championships_won =
(
    select max(championships_won)
    from teams
);
-- 36. The chief timing officer needs the ability to correct lap time records directly, unlike the rest of the analysis staff. Set up an access level that reflects this difference.
grant select, update
on laptimes
to 'chief_timing_officer'@'localhost';

-- 37. Identify which drivers have posted an average finishing position better than 5 across all their races this season — genuine championship contenders.
select
    d.driver_name,
    avg(lt.position) as average_finish
from drivers d
join laptimes lt
on d.driver_id = lt.driver_id
group by d.driver_name
having avg(lt.position) < 5;

-- 38. Flag each circuit as 'High-Speed', 'Technical', or 'Balanced' based on its total lap count relative to its length, to help engineers set up the car correctly.
select
    c.circuit_name,
    case
        when count(lt.lap_id) / c.length_Km > 120 then 'high-speed'
        when count(lt.lap_id) / c.length_Km > 80 then 'balanced'
        else 'technical'
    end as circuit_type
from circuits c
join races r
on c.circuit_id = r.circuit_id
join laptimes lt
on r.race_id = lt.race_id
group by c.circuit_name, c.length_Km;

-- 39. Find every team that has at least one driver who has posted a lap time at a circuit outside their home country.
select distinct
    t.team_name
from teams t
join drivers d
on t.team_id = d.team_id
join laptimes lt
on d.driver_id = lt.driver_id
join races r
on lt.race_id = r.race_id
join circuits c
on r.circuit_id = c.circuit_id
where t.base_country <> c.country;

-- 40. First tally each team's total pit stop count, then bring in driver details to see which drivers are contributing most to their team's total pit stops.
with teampitstops as
(
    select
        d.team_id,
        d.driver_id,
        sum(lt.pit_stop) as total_pit_stops
    from drivers d
    join laptimes lt
    on d.driver_id = lt.driver_id
    group by d.team_id, d.driver_id
)

select
    t.team_name,
    d.driver_name,
    tp.pit_stop
from teampitstops tp
join teams t
on tp.team_id = t.team_id
join drivers d
on tp.driver_id = d.driver_id
order by t.team_name;

-- 41. For the TV broadcast graphics, combine each driver's name and car number into a single readable label, separated by a dash.
select
    concat(driver_name, ' - ', car_number) as driver_label
from drivers;

-- (doubt)42 . List all races held at one of the three longest circuits by track length.
select
    r.race_name,
    c.circuit_name,
    c.length_Km
from races r
join circuits c
on r.circuit_id = c.circuit_id
where c.circuit_id in
(
    select circuit_id
    from circuits
    order by length_Km desc
    limit 3
);

-- 43. Group all races by the exact season year they belong to, to compare how the calendar has grown year over year.
select
    season_year,
    count(*) as total_races
from races
group by season_year
order by season_year;


-- 44. The broadcast graphics team needs a simplified, always-ready snapshot showing each driver's name, team, car number, and latest lap time, without the production crew having to reconstruct the full picture from scratch every race weekend.
create view driver_summary as
select
    d.driver_name,
    t.team_name,
    d.car_number,
    max(lt.lap_time_seconds) as latest_lap_time
from drivers d
join teams t
on d.team_id = t.team_id
left join laptimes lt
on d.driver_id = lt.driver_id
group by d.driver_name, t.team_name, d.car_number;

-- 45. Calculate a combined performance score per driver using their average lap time and finishing position as an intermediate result, then use that to rank the teams by overall performance.
with driverperformance as
(
    select
        d.driver_id,
        d.team_id,
        avg(lt.lap_time_seconds) as avg_lap_time,
        avg(lt.position) as avg_finish
    from drivers d
    join laptimes lt
    on d.driver_id = lt.driver_id
    group by d.driver_id, d.team_id
)

select
    t.team_name,
    avg(dp.avg_lap_time + dp.avg_finish) as performance_score
from driverperformance dp
join teams t
on dp.team_id = t.team_id
group by t.team_name
order by performance_score;


-- 46. Based on finishing position, tag each lap record as 'Podium Pace', 'Points Pace', or 'Midfield Pace', to help analysts describe a driver's race in simple terms.
select
    lap_id,
    driver_id,
    position,
    case
        when position <= 3 then 'podium pace'
        when position <= 10 then 'points pace'
        else 'midfield pace'
    end as pace_category
from laptimes;

-- 47. Count how many drivers are currently contracted to each team.
select
    t.team_name,
    count(d.driver_id) as total_drivers
from teams t
left join drivers d
on t.team_id = d.team_id
group by t.team_name;

-- 48. For a specific circuit hosting a night race, pull all races and check which ones started particularly late in the season.
select
    race_name,
    race_date
from races
where circuit_id = 1
and month(race_date) >= 9;

-- 49. Some circuits may not have hosted a single race yet this season. Identify exactly which ones, since this is a scheduling gap worth flagging.
select
    c.circuit_name
from circuits c
left join races r
on c.circuit_id = r.circuit_id
and r.season_year = year(curdate())
where r.race_id is null;

-- 50. The end-of-season report needs a single consolidated result: for every team, the number of drivers on their roster, their average lap time across the season, their total pit stop count, and a clear flag for any team whose average lap time has fallen below the grid-wide average.
with teamstats as
(
    select
        t.team_id,
        t.team_name,
        count(distinct d.driver_id) as total_drivers,
        avg(lt.lap_time_seconds) as avg_lap_time,
        sum(lt.pit_stop) as total_pit_stops
    from teams t
    left join drivers d
    on t.team_id = d.team_id
    left join laptimes lt
    on d.driver_id = lt.driver_id
    group by t.team_id, t.team_name
)

select *,
case
    when avg_lap_time <
    (select avg(lap_time_seconds) from laptimes)
    then 'below average'
    else 'above average'
end as performance
from teamstats;

-- 51. Find the single fastest lap ever recorded across the whole season — this could be the benchmark used for next year's track record board.
select *
from laptimes
order by lap_time_seconds
limit 1;

-- 52. Split all drivers into three roughly equal performance tiers based on their average lap time, to help design three different tiers of prize money.
select
    driver_id,
    avg(lap_time_seconds) as average_lap,
    ntile(3) over(order by avg(lap_time_seconds)) as performance_group
from laptimes
group by driver_id;

-- 53. Pull every lap time belonging specifically to the one driver who recorded the single fastest lap of the season.
select *
from laptimes
where driver_id =
(
    select driver_id
    from laptimes
    order by lap_time_seconds
    limit 1
);

-- 54. Some driver names were typed with inconsistent capitalization during registration. Produce a clean, uniformly capitalized list for the official entry list.
select
    concat(
        upper(left(driver_name,1)),
        lower(substring(driver_name,2))
    ) as driver_name
from drivers;

-- 55. After a recent data cleanup, a few lap records may now point to a driver ID that no longer exists in the system. Track down these orphaned records.
select
    lt.*
from laptimes lt
left join drivers d
on lt.driver_id = d.driver_id
where d.driver_id is null;
-- 56. For each team, count the number of pit stops logged across the season, and highlight any team with more than 150 — a possible sign of strategy issues or reliability trouble.
select
    t.team_name,
    sum(lt.pit_stop) as total_pit_stops
from teams t
join drivers d
on t.team_id = d.team_id
join laptimes lt
on d.driver_id = lt.driver_id
group by t.team_name
having sum(lt.pit_stop) > 150;

-- 57. Produce a single combined list of every circuit and every race together — including circuits with zero races and any race record that's somehow missing its circuit — so nothing gets left out of the audit.
select
    c.circuit_name,
    r.race_name
from circuits c
left join races r
on c.circuit_id = r.circuit_id

union

select
    c.circuit_name,
    r.race_name
from circuits c
right join races r
on c.circuit_id = r.circuit_id;

-- 58. Break this into two steps: first find each driver's most recent race date, then use that to identify which drivers haven't raced in the last two rounds.
WITH Driver_Last_Race AS (
    SELECT
        lt.driver_id,
        MAX(r.race_date) AS last_race_date
    FROM LapTimes lt
    JOIN Races r
        ON lt.race_id = r.race_id
    GROUP BY lt.driver_id
),
Last_Two_Rounds AS (
    SELECT race_date
    FROM Races
    ORDER BY race_date DESC
    LIMIT 2
)
SELECT
    d.driver_id,
    d.driver_name,
    dlr.last_race_date
FROM Drivers d
JOIN Driver_Last_Race dlr
    ON d.driver_id = dlr.driver_id
WHERE dlr.last_race_date <
      (SELECT MIN(race_date) FROM Last_Two_Rounds);

-- 59. Group laps by race and identify which races had an average lap time slower than the circuit's typical pace — a possible sign of poor weather conditions.
with circuitavg as
(
    select
        r.circuit_id,
        avg(lt.lap_time_seconds) as avg_time
    from races r
    join laptimes lt
    on r.race_id = lt.race_id
    group by r.circuit_id
)

select
    r.race_name,
    avg(lt.lap_time_seconds) as race_average
from races r
join laptimes lt
on r.race_id = lt.race_id
join circuitavg c
on r.circuit_id = c.circuit_id
group by r.race_id, r.race_name, c.avg_time
having avg(lt.lap_time_seconds) > c.avg_time;

-- 60. For each team, build a running count of pit stops over the course of the season, ordered by race date, to visualize how strategy has evolved.
select
    t.team_name,
    r.race_date,
    sum(lt.pit_stop) over
    (
        partition by t.team_id
        order by r.race_date
    ) as running_pit_stops
from teams t
join drivers d
on t.team_id = d.team_id
join laptimes lt
on d.driver_id = lt.driver_id
join races r
on lt.race_id = r.race_id;

-- 61. Find the slowest lap time ever recorded — this might point to a driver who had to nurse a damaged car home.
select *
from laptimes
order by lap_time_seconds desc
limit 1;

-- 62. The system currently lets someone log a finishing position of 47 in a 20-car race by mistake. What change would permanently make this impossible going forward?
alter table laptimes
add constraint chk_finish_position
check (position between 1 and 20);

-- 63. For each driver, flag any of their own laps where the recorded lap time is noticeably slower than that same driver's own typical pace — a possible sign of a spin or damage.
with driveravg as
(
    select
        driver_id,
        avg(lap_time_seconds) as avg_lap
    from laptimes
    group by driver_id
)

select
    lt.driver_id,
    lt.lap_id,
    lt.lap_time_seconds
from laptimes lt
join driveravg d
on lt.driver_id = d.driver_id
where lt.lap_time_seconds > d.avg_lap;

-- 64. A data entry clerk accidentally types a lap time as a negative number. How do you make sure this kind of entry is rejected the moment it's submitted?
alter table laptimes
add constraint chk_lap_time
check (lap_time_seconds > 0);

-- 65. For every race, surface the single fastest lap recorded in it without losing any of that race's other lap records in the process — every lap should still show up in the result.
select
    lt.*,
    min(lap_time_seconds) over(partition by race_id) as fastest_race_lap
from laptimes lt;

-- 66. For each circuit, smooth out lap-to-lap variation by calculating an average lap time using only the current lap and the two immediately before it.
select
    driver_id,
    lap_number,
    lap_time_seconds,
    avg(lap_time_seconds) over(
        partition by driver_id
        order by lap_number
        rows between 2 preceding and current row
    ) as moving_average
from laptimes;

-- 67. For every team on the grid, list out all the circuits where at least one of their drivers has posted a lap time.
select distinct
    t.team_name,
    c.circuit_name
from teams t
join drivers d
on t.team_id = d.team_id
join laptimes lt
on d.driver_id = lt.driver_id
join races r
on lt.race_id = r.race_id
join circuits c
on r.circuit_id = c.circuit_id
order by t.team_name;

-- 68. The live timing dashboard constantly filters by race and lap number together, and the two filters are almost always used side by side. How would you set the database up so this specific combined search runs faster?
create index idx_race_lap
on laptimes(race_id, lap_number);

-- 69. Pull every race that took place during the month of June across all seasons, to study how mid-season form typically shifts.
select *
from races
where month(race_date) = 6;

-- 70. The league commissioner wants a single number for the season wrap-up: exactly how many laps have been recorded across the entire championship so far.
select
count(*) as total_laps
from laptimes;

-- 71. For each driver, work out how many days have passed since their date of birth — the broadcast team wants live age figures on screen during the race.
select
driver_name,
datediff(curdate(), date_of_birth) as age_in_days
from drivers;

-- 72. The commercial partnerships team keeps asking for the same list — every team along with its base country and championship count. Set up something they can pull directly, without you explaining the underlying tables every time they ask.
create view team_details as
select
team_name,
base_country,
championships_won
from teams;

-- 73. A bulk import left several circuit names with accidental leading or trailing spaces. Clean these up before they go into the printed race programme.
update circuits
set circuit_name = trim(circuit_name);

-- 74. A new data analyst is joining the strategy team and should only be able to look at lap and race data, never change any of it. Set up their access accordingly.
create user 'strategy_analyst'@'localhost'
identified by 'password123';

grant select
on apexgp.races
to 'strategy_analyst'@'localhost';

grant select
on apexgp.laptimes
to 'strategy_analyst'@'localhost';

-- 75. Two team principals accidentally try to register the same car number for two different drivers tthis season. What should stop this from happening?
alter table drivers
add constraint unique_car_number
unique(car_number);
