USE f1_analytics;
CREATE VIEW driver_details AS
SELECT 
  driverId,
  CONCAT(forename, ' ', surname) AS driver_name
FROM drivers;




-- Fastest Average Lap Times per Driver in a Season
SELECT 
  dd.driverId,
  dd.driver_name,
  r.year,
  ROUND(AVG(lt.milliseconds)/1000,3) AS avg_laptime_sec
  FROM lap_times lt
  JOIN driver_details dd ON lt.driverId=dd.driverId
  JOIN races r ON lt.raceId=r.raceId
  GROUP BY dd.driverId, dd.driver_name, r.year
  ORDER BY avg_laptime_sec ASC
  LIMIT 10;
  
  -- Race with max pitstop in a season
  
  SELECT ps.raceId,
  r.year,
  r.name AS race_name,
  dd.driverId,dd.driver_name,
  COUNT(*) AS total_pitstops
  FROM pit_stops ps
  JOIN races r on ps.raceId=r.raceId
  JOIN driver_details  dd on ps.driverId=dd.driverId
  GROUP BY ps.raceId, dd.driverId, r.year, r.name, dd.driver_name
  order by total_pitstops DESC
  LIMIT 1;
  
  
  -- Average pit stop time per team per season
  SELECT r.year,
  c.name AS team_name,
  ROUND(AVG(ps.milliseconds)/1000,3) AS avg_pit_time_sec
  FROM pit_stops ps
  JOIN races r ON ps.raceId=r.raceId
  JOIN results res ON ps.raceId=res.raceId AND ps.driverId=res.driverId
  join constructors c on res.constructorId=c.constructorId
  GROUP BY r.year,c.name
  ORDER BY r.year,avg_pit_time_sec
  LIMIT 10;
  
-- Fastest pit crews across circuits
  SELECT cir.name AS circuit_name,
  c.name as team_name,
  ROUND(AVG(ps.milliseconds)/1000,3) AS avg_pit_time_sec
  FROM pit_stops ps
  JOIN races r ON ps.raceId=r.raceId
  JOIN circuits cir ON r.circuitId=cir.circuitId
  JOIN results res on ps.raceId=res.raceId AND ps.driverId=res.driverId
  JOIN constructors c ON res.constructorId = c.constructorId
WHERE ps.milliseconds IS NOT NULL
GROUP BY cir.circuitId,cir.name, c.constructorId,team_name
ORDER BY avg_pit_time_sec ASC;

-- Laps when most pit stops happen (understand strategy)
SELECT
  lap,
  COUNT(*) AS pitstop_count
FROM pit_stops
WHERE lap > 1
GROUP BY lap
ORDER BY pitstop_count DESC
LIMIT 10;


