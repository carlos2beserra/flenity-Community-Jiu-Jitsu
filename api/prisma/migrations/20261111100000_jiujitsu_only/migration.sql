BEGIN;

CREATE TEMPORARY TABLE "_JiuJitsuModality" AS
SELECT "id", "academyId"
FROM "Modality"
WHERE lower(regexp_replace("name", '[^a-zA-Z0-9]', '', 'g')) LIKE '%jiujitsu%'
   OR lower(regexp_replace("name", '[^a-zA-Z0-9]', '', 'g')) LIKE 'bjj%'
   OR lower(regexp_replace("name", '[^a-zA-Z0-9]', '', 'g')) LIKE 'jjb%';

INSERT INTO "Modality" ("id", "academyId", "name")
SELECT gen_random_uuid()::text, a."id", 'Jiu-Jitsu'
FROM "Academy" a
WHERE NOT EXISTS (
  SELECT 1 FROM "_JiuJitsuModality" bjj WHERE bjj."academyId" = a."id"
);

INSERT INTO "_JiuJitsuModality" ("id", "academyId")
SELECT m."id", m."academyId"
FROM "Modality" m
WHERE m."name" = 'Jiu-Jitsu'
  AND NOT EXISTS (
    SELECT 1 FROM "_JiuJitsuModality" bjj WHERE bjj."id" = m."id"
  );

INSERT INTO "Belt" ("id", "modalityId", "name", "color", "order", "minClasses", "maxDegrees")
SELECT gen_random_uuid()::text, bjj."id", belt."name", belt."color", belt."order", belt."minClasses", belt."maxDegrees"
FROM "_JiuJitsuModality" bjj
CROSS JOIN (VALUES
  ('Branca', '#f5f5f5', 0, 40, 4),
  ('Azul', '#1e5bd6', 1, 120, 4),
  ('Roxa', '#7b2fbf', 2, 150, 4),
  ('Marrom', '#7a4a21', 3, 150, 4),
  ('Preta', '#111111', 4, 300, 4)
) AS belt("name", "color", "order", "minClasses", "maxDegrees")
WHERE NOT EXISTS (
  SELECT 1 FROM "Belt" existing WHERE existing."modalityId" = bjj."id"
);

DELETE FROM "Invoice" i
USING "Membership" membership
WHERE i."membershipId" = membership."id"
  AND NOT EXISTS (
    SELECT 1
    FROM "PlanModality" pm
    JOIN "_JiuJitsuModality" bjj ON bjj."id" = pm."modalityId"
    WHERE pm."planId" = membership."planId"
  );

DELETE FROM "Membership" membership
WHERE NOT EXISTS (
  SELECT 1
  FROM "PlanModality" pm
  JOIN "_JiuJitsuModality" bjj ON bjj."id" = pm."modalityId"
  WHERE pm."planId" = membership."planId"
);

DELETE FROM "Plan" plan
WHERE NOT EXISTS (
  SELECT 1
  FROM "PlanModality" pm
  JOIN "_JiuJitsuModality" bjj ON bjj."id" = pm."modalityId"
  WHERE pm."planId" = plan."id"
);

DELETE FROM "Lead"
WHERE "interest" IS NOT NULL
  AND lower(regexp_replace("interest", '[^a-zA-Z0-9]', '', 'g')) NOT LIKE '%jiujitsu%'
  AND lower(regexp_replace("interest", '[^a-zA-Z0-9]', '', 'g')) NOT LIKE 'bjj%'
  AND lower(regexp_replace("interest", '[^a-zA-Z0-9]', '', 'g')) NOT LIKE 'jjb%';

DELETE FROM "Modality" modality
WHERE NOT EXISTS (
  SELECT 1 FROM "_JiuJitsuModality" bjj WHERE bjj."id" = modality."id"
);

DROP TABLE "WorkoutSet";
DROP TABLE "WorkoutExercise";
DROP TABLE "WorkoutPlanExercise";
DROP TABLE "WorkoutSession";
DROP TABLE "WorkoutPlanDay";
DROP TABLE "WorkoutPlan";
DROP TABLE "StudentAssessment";
DROP TABLE "WeightExercise";
DROP TABLE "_JiuJitsuModality";

COMMIT;
