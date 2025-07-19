USE f1_analytics;

-- =============================================================================
-- HELPER VIEWS
-- =============================================================================

-- Driver details helper view
CREATE OR REPLACE VIEW vw_driver_details AS
SELECT 
  driverId,
  CONCAT(forename, ' ', surname) AS driver_name,
  forename,
  surname
FROM drivers;

-- =============================================================================
-- DRIVER PERFORMANCE VIEWS
-- =============================================================================

-- Driver career statistics
CREATE OR REPLACE VIEW vw_driver_career_stats AS
SELECT 
  dd.driverId,
  dd.driver_name,
  COUNT(r.resultId) AS total_races,
  SUM(CASE WHEN r.position = 1 THEN 1 ELSE 0 END) AS wins,
  SUM(CASE WHEN r.position <= 3 THEN 1 ELSE 0 END) AS podiums,
  SUM(CASE WHEN r.position <= 10 THEN 1 ELSE 0 END) AS points_finishes
FROM results r
JOIN vw_driver_details dd ON r.driverId = dd.driverId
GROUP BY dd.driverId, dd.driver_name;

-- Driver normalized points (25-18-15 system)
CREATE OR REPLACE VIEW vw_driver_normalized_points AS
SELECT 
  dd.driverId,
  dd.driver_name,
  ROUND(SUM(
    CASE r.positionOrder
      WHEN 1 THEN 25
      WHEN 2 THEN 18
      WHEN 3 THEN 15
      WHEN 4 THEN 12
      WHEN 5 THEN 10
      WHEN 6 THEN 8
      WHEN 7 THEN 6
      WHEN 8 THEN 4
      WHEN 9 THEN 2
      WHEN 10 THEN 1
      ELSE 0
    END
  ), 2) AS normalized_total_points,
  COUNT(CASE WHEN r.positionOrder = 1 THEN 1 END) AS total_wins,
  COUNT(r.resultId) AS total_races
FROM results r
JOIN vw_driver_details dd ON r.driverId = dd.driverId
GROUP BY dd.driverId, dd.driver_name;

-- Driver yearly progression
CREATE OR REPLACE VIEW vw_driver_yearly_progression AS
SELECT 
  d.driverId,
  dd.driver_name,
  ra.year,
  ds.points,
  ds.position AS final_rank
FROM driver_standings ds
JOIN drivers d ON ds.driverId = d.driverId
JOIN vw_driver_details dd ON dd.driverId = d.driverId
JOIN races ra ON ds.raceId = ra.raceId
WHERE ra.year >= 2010
  AND ra.raceId IN (
    SELECT MAX(raceId)
    FROM races
    GROUP BY year
  );

-- Driver DNF statistics
CREATE OR REPLACE VIEW vw_driver_dnf_stats AS
SELECT 
  d.driverId,
  dd.driver_name,
  COUNT(*) AS total_races,
  SUM(CASE 
        WHEN s.status LIKE '%accident%' OR s.status LIKE '%disqualified%' 
          OR s.status LIKE '%engine%' OR s.status LIKE '%gearbox%' 
          OR s.status LIKE '%suspension%' OR s.status LIKE '%retired%' 
          OR s.status LIKE '%did not finish%' 
        THEN 1 ELSE 0 
      END) AS dnf_count,
  ROUND(
    100 * SUM(CASE 
               WHEN s.status LIKE '%accident%' OR s.status LIKE '%disqualified%' 
                 OR s.status LIKE '%engine%' OR s.status LIKE '%gearbox%' 
                 OR s.status LIKE '%suspension%' OR s.status LIKE '%retired%' 
                 OR s.status LIKE '%did not finish%' 
               THEN 1 ELSE 0 
             END) / COUNT(*), 2) AS dnf_percentage
FROM results r
JOIN drivers d ON r.driverId = d.driverId
JOIN vw_driver_details dd ON dd.driverId = d.driverId
JOIN status s ON r.statusId = s.statusId
GROUP BY d.driverId, dd.driver_name;

-- Driver grid vs finish performance
CREATE OR REPLACE VIEW vw_driver_grid_performance AS
SELECT 
  dd.driverId,
  dd.driver_name,
  ra.year,
  COUNT(*) AS races_counted,
  ROUND(AVG(r.grid - r.positionOrder), 2) AS avg_positions_gained,
  ROUND(AVG(r.grid), 2) AS avg_grid_position,
  ROUND(AVG(r.positionOrder), 2) AS avg_finish_position
FROM results r
JOIN vw_driver_details dd ON r.driverId = dd.driverId
JOIN races ra ON ra.raceId = r.raceId
WHERE r.grid > 0 AND r.positionOrder > 0  
  AND ra.year BETWEEN 2019 AND 2024
GROUP BY dd.driverId, dd.driver_name, ra.year;

-- Driver teammate comparison
CREATE OR REPLACE VIEW vw_driver_teammate_comparison AS
WITH recent_races AS (
  SELECT raceId, year FROM races
  WHERE year BETWEEN 2019 AND 2024
),
teammate_duels AS (
  SELECT 
    r1.driverId as driver,
    r2.driverId AS teammate,
    r1.raceId,
    r1.constructorId,
    r1.positionOrder as driver_pos,
    r2.positionOrder as teammate_pos
  FROM results r1
  JOIN results r2
    ON r1.raceId = r2.raceId
    AND r1.constructorId = r2.constructorId
    AND r1.driverId <> r2.driverId
  JOIN recent_races rr ON r1.raceId = rr.raceId
  WHERE r1.positionOrder > 0 AND r2.positionOrder > 0
),
duel_wins AS (
  SELECT 
    driver,
    COUNT(*) AS times_beaten_teammate,
    COUNT(CASE WHEN driver_pos < teammate_pos THEN 1 END) AS wins_vs_teammate,
    COUNT(*) AS total_teammate_battles
  FROM teammate_duels
  GROUP BY driver
)
SELECT 
  dd.driver_name,
  dw.times_beaten_teammate,
  dw.wins_vs_teammate,
  dw.total_teammate_battles,
  ROUND(100.0 * dw.wins_vs_teammate / dw.total_teammate_battles, 2) AS teammate_win_percentage
FROM duel_wins dw
JOIN vw_driver_details dd ON dw.driver = dd.driverId;

-- =============================================================================
-- CONSTRUCTOR PERFORMANCE VIEWS
-- =============================================================================

-- Constructor championship history
CREATE OR REPLACE VIEW vw_constructor_championships AS
WITH race_years AS (
    SELECT raceId, year
    FROM races
    WHERE year BETWEEN 1950 AND 2024
),
constructor_points AS (
    SELECT 
        r.constructorId,
        ry.year,
        SUM(CASE r.positionOrder
            WHEN 1 THEN 25
            WHEN 2 THEN 18
            WHEN 3 THEN 15
            WHEN 4 THEN 12
            WHEN 5 THEN 10
            WHEN 6 THEN 8
            WHEN 7 THEN 6
            WHEN 8 THEN 4
            WHEN 9 THEN 2
            WHEN 10 THEN 1
            ELSE 0
        END) AS total_points
    FROM results r
    JOIN race_years ry ON r.raceId = ry.raceId
    GROUP BY r.constructorId, ry.year
),
constructor_champions AS (
    SELECT
        cp.year,
        cp.constructorId,
        cp.total_points,
        RANK() OVER(PARTITION BY cp.year ORDER BY cp.total_points DESC) AS championship_position
    FROM constructor_points cp
)
SELECT 
    cc.year,
    c.name AS constructor_name,
    cc.total_points,
    cc.championship_position
FROM constructor_champions cc
JOIN constructors c ON cc.constructorId = c.constructorId;

-- Constructor average performance
CREATE OR REPLACE VIEW vw_constructor_avg_performance AS
WITH race_years AS (
  SELECT raceId, year
  FROM races
  WHERE year BETWEEN 1950 AND 2024
),
constructor_points AS (
  SELECT 
    r.constructorId,
    ry.year,
    SUM(CASE r.positionOrder
        WHEN 1 THEN 25
        WHEN 2 THEN 18
        WHEN 3 THEN 15
        WHEN 4 THEN 12
        WHEN 5 THEN 10
        WHEN 6 THEN 8
        WHEN 7 THEN 6
        WHEN 8 THEN 4
        WHEN 9 THEN 2
        WHEN 10 THEN 1
        ELSE 0
    END) AS total_points
  FROM results r
  JOIN race_years ry ON r.raceId = ry.raceId
  GROUP BY r.constructorId, ry.year
),
race_counts AS (
  SELECT year, COUNT(*) AS race_count
  FROM races
  WHERE year BETWEEN 1950 AND 2024
  GROUP BY year
),
constructor_avg_points AS (
  SELECT 
    cp.constructorId,
    cp.year,
    cp.total_points,
    rc.race_count,
    1.0 * cp.total_points / rc.race_count AS avg_points_per_race
  FROM constructor_points cp
  JOIN race_counts rc ON cp.year = rc.year
)
SELECT 
  c.name AS constructor_name,
  cap.year,
  cap.total_points,
  cap.race_count,
  ROUND(cap.avg_points_per_race, 2) AS avg_points_per_race
FROM constructor_avg_points cap
JOIN constructors c ON cap.constructorId = c.constructorId;

-- Constructor dominance by decade
CREATE OR REPLACE VIEW vw_constructor_decade_dominance AS
WITH race_years AS (
  SELECT raceId, year
  FROM races
  WHERE year BETWEEN 1950 AND 2024
),
points_per_result AS (
  SELECT
    r.constructorId,
    ry.year,
    CASE r.positionOrder
      WHEN 1 THEN 25
      WHEN 2 THEN 18
      WHEN 3 THEN 15
      WHEN 4 THEN 12
      WHEN 5 THEN 10
      WHEN 6 THEN 8
      WHEN 7 THEN 6
      WHEN 8 THEN 4
      WHEN 9 THEN 2
      WHEN 10 THEN 1
      ELSE 0
    END AS points
  FROM results r
  JOIN race_years ry ON r.raceId = ry.raceId
),
points_by_decade AS (
  SELECT
    p.constructorId,
    FLOOR(p.year / 10) * 10 AS decade,
    SUM(p.points) AS total_points
  FROM points_per_result p
  GROUP BY p.constructorId, FLOOR(p.year / 10) * 10
),
ranked_constructors AS (
  SELECT 
    pd.decade,
    pd.constructorId,
    pd.total_points,
    RANK() OVER(PARTITION BY pd.decade ORDER BY pd.total_points DESC) AS decade_rank
  FROM points_by_decade pd
)
SELECT 
  rc.decade,
  c.name AS constructor_name,
  rc.total_points,
  rc.decade_rank
FROM ranked_constructors rc
JOIN constructors c ON rc.constructorId = c.constructorId;

-- Best driver-constructor combinations
CREATE OR REPLACE VIEW vw_best_driver_constructor_combos AS
SELECT 
  d.forename,
  d.surname,
  c.name AS constructor_name,
  CONCAT(d.forename, ' ', d.surname, ' - ', c.name) AS combo_name,
  COUNT(r.resultId) AS races_together,
  SUM(
    CASE r.positionOrder
      WHEN 1 THEN 25
      WHEN 2 THEN 18
      WHEN 3 THEN 15
      WHEN 4 THEN 12
      WHEN 5 THEN 10
      WHEN 6 THEN 8
      WHEN 7 THEN 6
      WHEN 8 THEN 4
      WHEN 9 THEN 2
      WHEN 10 THEN 1
      ELSE 0
    END
  ) AS total_points,
  SUM(CASE WHEN r.positionOrder = 1 THEN 1 ELSE 0 END) AS wins,
  SUM(CASE WHEN r.positionOrder <= 3 THEN 1 ELSE 0 END) AS podiums,
  ROUND(AVG(r.positionOrder), 2) AS avg_finish_position
FROM results r
JOIN drivers d ON r.driverId = d.driverId
JOIN constructors c ON r.constructorId = c.constructorId
WHERE r.positionOrder > 0
GROUP BY d.forename, d.surname, c.name;

-- =============================================================================
-- RACE AND SEASON ANALYSIS VIEWS
-- =============================================================================

-- Race retirement statistics
CREATE OR REPLACE VIEW vw_race_retirements AS
SELECT 
  r.raceId,
  ra.year,
  ra.name AS race_name,
  ci.name AS circuit_name,
  COUNT(*) AS num_retirements,
  COUNT(CASE WHEN r.statusId = 1 THEN 1 END) AS finishers,
  ROUND(100.0 * COUNT(*) / (COUNT(*) + COUNT(CASE WHEN r.statusId = 1 THEN 1 END)), 2) AS retirement_percentage
FROM results r
JOIN status s ON r.statusId = s.statusId
JOIN races ra ON r.raceId = ra.raceId
JOIN circuits ci ON ra.circuitId = ci.circuitId
WHERE r.statusId > 1
GROUP BY ra.raceId, ra.year, ra.name, ci.name;

-- Race overtaking statistics
CREATE OR REPLACE VIEW vw_race_overtakes AS
SELECT 
  ra.raceId,
  ra.year,
  ra.name AS race_name,
  ci.name AS circuit_name,
  SUM(r.grid - r.positionOrder) AS total_position_changes,
  AVG(r.grid - r.positionOrder) AS avg_position_change,
  COUNT(*) AS total_classified_finishers
FROM results r
JOIN races ra ON r.raceId = ra.raceId
JOIN circuits ci ON ra.circuitId = ci.circuitId
WHERE r.grid > 0 AND r.positionOrder > 0
GROUP BY ra.raceId, ra.year, ra.name, ci.name;

-- Circuit crash/retirement rates
CREATE OR REPLACE VIEW vw_circuit_dnf_rates AS
WITH dnf_statuses AS (
  SELECT statusId
  FROM status
  WHERE status LIKE '%accident%'
     OR status LIKE '%retired%'
     OR status LIKE '%engine%'
     OR status LIKE '%disqualified%'
     OR status LIKE '%gearbox%'
     OR status LIKE '%suspension%'
     OR status LIKE '%did not finish%'
),
circuit_dnf_stats AS (
  SELECT
    ci.circuitId,
    ci.name AS circuit_name,
    ci.country,
    COUNT(r.resultId) AS total_results,
    SUM(CASE WHEN r.statusId IN (SELECT statusId FROM dnf_statuses) THEN 1 ELSE 0 END) AS total_dnfs
  FROM results r
  JOIN races ra ON r.raceId = ra.raceId
  JOIN circuits ci ON ra.circuitId = ci.circuitId
  GROUP BY ci.circuitId, ci.name, ci.country
)
SELECT
  circuit_name,
  country,
  total_results,
  total_dnfs,
  ROUND(100.0 * total_dnfs / total_results, 2) AS dnf_percentage
FROM circuit_dnf_stats
WHERE total_results > 50;

-- Driver performance by circuit
CREATE OR REPLACE VIEW vw_driver_circuit_performance AS
SELECT
  r.driverId,
  dd.driver_name,
  ra.circuitId,
  c.name AS circuit_name,
  COUNT(*) AS races_at_circuit,
  SUM(r.points) AS total_points,
  COUNT(CASE WHEN r.positionOrder = 1 THEN 1 END) AS wins,
  COUNT(CASE WHEN r.positionOrder <= 3 THEN 1 END) AS podiums,
  ROUND(AVG(r.positionOrder), 2) AS avg_finish_position,
  ROUND(AVG(r.grid), 2) AS avg_grid_position
FROM results r
JOIN races ra ON r.raceId = ra.raceId
JOIN circuits c ON ra.circuitId = c.circuitId
JOIN vw_driver_details dd ON r.driverId = dd.driverId
WHERE r.positionOrder > 0 AND r.grid > 0
GROUP BY r.driverId, dd.driver_name, ra.circuitId, c.name;

-- =============================================================================
-- QUALIFYING AND SPRINT VIEWS
-- =============================================================================

-- Driver qualifying vs race performance
CREATE OR REPLACE VIEW vw_driver_qualifying_race_performance AS
SELECT 
  d.driverId,
  CONCAT(d.forename, ' ', d.surname) AS driver_name,
  COUNT(*) AS total_races,
  ROUND(AVG(CASE WHEN r.grid > 0 THEN r.grid END), 2) AS avg_qualifying_pos,
  ROUND(AVG(CASE WHEN r.positionOrder > 0 THEN r.positionOrder END), 2) AS avg_finish_position,
  ROUND(AVG(r.positionOrder - r.grid), 2) AS avg_position_change,
  COUNT(CASE WHEN r.positionOrder - r.grid > 0 THEN 1 END) AS races_lost_positions,
  COUNT(CASE WHEN r.positionOrder - r.grid < 0 THEN 1 END) AS races_gained_positions
FROM results r
JOIN drivers d ON r.driverId = d.driverId
WHERE r.grid > 0 AND r.positionOrder > 0
GROUP BY d.driverId, driver_name;

-- Sprint vs race winners comparison
CREATE OR REPLACE VIEW vw_sprint_vs_race_winners AS
SELECT
  ra.year,
  ra.round,
  ra.name AS race_name,
  CONCAT(ds.forename, ' ', ds.surname) AS sprint_winner,
  cs.name AS sprint_team,
  CONCAT(df.forename, ' ', df.surname) AS race_winner,
  cf.name AS race_team,
  CASE
    WHEN ds.driverId = df.driverId THEN 'Same Driver'
    WHEN cs.constructorId = cf.constructorId THEN 'Same Team'
    ELSE 'Different'
  END AS winner_comparison
FROM races ra
JOIN sprint_results sr ON ra.raceId = sr.raceId AND sr.positionOrder = 1
JOIN drivers ds ON sr.driverId = ds.driverId
JOIN constructors cs ON sr.constructorId = cs.constructorId
JOIN results r ON ra.raceId = r.raceId AND r.positionOrder = 1
JOIN drivers df ON r.driverId = df.driverId
JOIN constructors cf ON r.constructorId = cf.constructorId
WHERE ra.year >= 2021;

-- =============================================================================
-- PITSTOP AND LAPTIME VIEWS
-- =============================================================================

-- Driver lap time performance
CREATE OR REPLACE VIEW vw_driver_laptime_performance AS
SELECT 
  dd.driverId,
  dd.driver_name,
  r.year,
  COUNT(*) AS total_laps,
  ROUND(AVG(lt.milliseconds)/1000, 3) AS avg_laptime_sec,
  ROUND(MIN(lt.milliseconds)/1000, 3) AS fastest_laptime_sec,
  ROUND(MAX(lt.milliseconds)/1000, 3) AS slowest_laptime_sec
FROM lap_times lt
JOIN vw_driver_details dd ON lt.driverId = dd.driverId
JOIN races r ON lt.raceId = r.raceId
GROUP BY dd.driverId, dd.driver_name, r.year;

-- Driver pitstop statistics
CREATE OR REPLACE VIEW vw_driver_pitstop_stats AS
SELECT 
  ps.driverId,
  dd.driver_name,
  r.year,
  COUNT(*) AS total_pitstops,
  ROUND(AVG(ps.milliseconds)/1000, 3) AS avg_pitstop_time_sec,
  ROUND(MIN(ps.milliseconds)/1000, 3) AS fastest_pitstop_sec,
  ROUND(MAX(ps.milliseconds)/1000, 3) AS slowest_pitstop_sec,
  COUNT(DISTINCT ps.raceId) AS races_with_pitstops
FROM pit_stops ps
JOIN vw_driver_details dd ON ps.driverId = dd.driverId
JOIN races r ON ps.raceId = r.raceId
WHERE ps.milliseconds IS NOT NULL
GROUP BY ps.driverId, dd.driver_name, r.year;

-- Team pitstop performance by season
CREATE OR REPLACE VIEW vw_team_pitstop_performance AS
SELECT 
  r.year,
  c.name AS team_name,
  COUNT(*) AS total_pitstops,
  ROUND(AVG(ps.milliseconds)/1000, 3) AS avg_pit_time_sec,
  ROUND(MIN(ps.milliseconds)/1000, 3) AS fastest_pit_time_sec,
  ROUND(MAX(ps.milliseconds)/1000, 3) AS slowest_pit_time_sec
FROM pit_stops ps
JOIN races r ON ps.raceId = r.raceId
JOIN results res ON ps.raceId = res.raceId AND ps.driverId = res.driverId
JOIN constructors c ON res.constructorId = c.constructorId
WHERE ps.milliseconds IS NOT NULL
GROUP BY r.year, c.name;

-- Pitstop strategy analysis
CREATE OR REPLACE VIEW vw_pitstop_strategy AS
SELECT
  lap,
  COUNT(*) AS pitstop_count,
  ROUND(AVG(milliseconds)/1000, 3) AS avg_pitstop_time_sec,
  COUNT(DISTINCT raceId) AS races_with_pitstops_this_lap
FROM pit_stops
WHERE lap > 1 AND milliseconds IS NOT NULL
GROUP BY lap;

-- =============================================================================
-- CHAMPIONSHIP TRENDS VIEWS
-- =============================================================================

-- Championship leadership changes
CREATE OR REPLACE VIEW vw_championship_leadership AS
WITH first_half_leader AS (
  SELECT 
    r.year, 
    res.driverId, 
    dd.driver_name, 
    SUM(res.points) AS first_half_points,
    ROW_NUMBER() OVER (PARTITION BY r.year ORDER BY SUM(res.points) DESC) AS first_half_rank
  FROM results res
  JOIN races r ON res.raceId = r.raceId
  JOIN vw_driver_details dd ON dd.driverId = res.driverId
  WHERE r.year >= 2010 AND r.round <= 10
  GROUP BY r.year, res.driverId, dd.driver_name
),
final_champion AS (
  SELECT 
    r.year, 
    res.driverId, 
    dd.driver_name AS champion_name,
    SUM(res.points) AS full_season_points,
    ROW_NUMBER() OVER (PARTITION BY r.year ORDER BY SUM(res.points) DESC) AS final_rank
  FROM results res
  JOIN races r ON res.raceId = r.raceId
  JOIN vw_driver_details dd ON dd.driverId = res.driverId
  WHERE r.year >= 2010
  GROUP BY r.year, res.driverId, dd.driver_name
)
SELECT 
  fh.year,
  fh.driver_name AS first_half_leader,
  fh.first_half_points,
  fc.champion_name AS season_champion,
  fc.full_season_points,
  CASE WHEN fh.driverId = fc.driverId THEN 'Same' ELSE 'Different' END AS leadership_consistency
FROM first_half_leader fh
JOIN final_champion fc ON fh.year = fc.year
WHERE fh.first_half_rank = 1 AND fc.final_rank = 1;

-- Close title fights
CREATE OR REPLACE VIEW vw_close_title_fights AS
WITH last_race_per_year AS (
  SELECT year, MAX(raceId) AS last_raceId
  FROM races
  GROUP BY year
),
standings_last_race AS (
  SELECT 
    r.year,
    cs.constructorId,
    c.name AS constructor_name,
    cs.points
  FROM constructor_standings cs
  JOIN races r ON cs.raceId = r.raceId
  JOIN constructors c ON cs.constructorId = c.constructorId
  JOIN last_race_per_year lr ON r.raceId = lr.last_raceId
),
ranked_constructors AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY year ORDER BY points DESC) AS championship_position
  FROM standings_last_race
),
top_positions AS (
  SELECT year, constructor_name, points, championship_position
  FROM ranked_constructors
  WHERE championship_position <= 3
)
SELECT 
  year,
  constructor_name,
  points,
  championship_position,
  points - LAG(points) OVER (PARTITION BY year ORDER BY championship_position DESC) AS points_behind_leader
FROM top_positions;

-- =============================================================================
-- SUMMARY STATISTICS VIEW
-- =============================================================================

-- Overall F1 statistics summary
CREATE OR REPLACE VIEW vw_f1_summary_stats AS
SELECT
  (SELECT COUNT(*) FROM races) AS total_races,
  (SELECT COUNT(*) FROM drivers) AS total_drivers,
  (SELECT COUNT(*) FROM constructors) AS total_constructors,
  (SELECT COUNT(*) FROM circuits) AS total_circuits,
  (SELECT MIN(year) FROM races) AS first_season,
  (SELECT MAX(year) FROM races) AS latest_season,
  (SELECT COUNT(*) FROM results WHERE positionOrder = 1) AS total_wins_recorded,
  (SELECT COUNT(*) FROM results WHERE positionOrder <= 3) AS total_podiums_recorded;

-- Create indexes for better performance
CREATE INDEX idx_results_driver_race ON results(driverId, raceId);
CREATE INDEX idx_results_constructor_race ON results(constructorId, raceId);
CREATE INDEX idx_races_year ON races(year);
CREATE INDEX idx_lap_times_driver_race ON lap_times(driverId, raceId);
CREATE INDEX idx_pit_stops_driver_race ON pit_stops(driverId, raceId);
