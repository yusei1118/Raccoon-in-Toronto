
-- 行政区別のサマリーと月次推移を組み合わせた分析データ
WITH ward_base AS (
    -- 1. 行政区ごとの基本統計（面積、総件数、密度）
    -- GEOGRAPHY型でのGROUP BYはできないため、まずIDと名前で集計
    SELECT
      w.AREA_NAME,
      w.AREA_SHORT_CODE,
      ANY_VALUE(w.geometry) AS geojson_str,
      -- 面積計算 (m2 -> km2)
      ST_AREA(ST_GEOGFROMGEOJSON(ANY_VALUE(w.geometry))) / 1000000
        AS area_sq_km,
      COUNT(*) AS total_incidents
    FROM `lunar-carving-457020-h5.clean.Raccoon In Toronto` AS r
    JOIN `lunar-carving-457020-h5.clean.wards` AS w
      ON r.ward_id = w.AREA_SHORT_CODE
    GROUP BY 1, 2
  ),
  ward_stats AS (
    SELECT *, total_incidents / NULLIF(area_sq_km, 0) AS incidents_per_sq_km
    FROM ward_base
  ),
  monthly_trends AS (
    -- 2. 行政区×月別の目撃件数
    SELECT
      ward_id,
      EXTRACT(MONTH FROM date) AS incident_month,
      COUNT(*) AS monthly_incidents,
      SUM(units_observed) AS total_raccoons_observed,
      AVG(raccoon_confidence_level) AS avg_confidence
    FROM `lunar-carving-457020-h5.clean.Raccoon In Toronto`
    GROUP BY 1, 2
  )

-- 3. 全てを統合して可視化用データを作成
SELECT
  ws.AREA_NAME,
  ws.AREA_SHORT_CODE,
  ws.area_sq_km,
  ws.total_incidents AS grand_total_incidents,
  ws.incidents_per_sq_km,
  mt.incident_month,
  mt.monthly_incidents,
  mt.total_raccoons_observed,
  mt.avg_confidence,
  -- ここを修正：文字列をGEOGRAPHY型に変換して出力
  ST_GEOGFROMGEOJSON(ws.geojson_str) AS ward_geography 
FROM ward_stats ws
JOIN monthly_trends mt
  ON ws.AREA_SHORT_CODE = mt.ward_id
ORDER BY grand_total_incidents DESC, incident_month ASC