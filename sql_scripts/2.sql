\c info21_db;

CREATE TABLE peers
    (
        nickname varchar NOT NULL
            PRIMARY KEY
            UNIQUE,
        birthday date NOT NULL
    );

CREATE TABLE tasks
    (
        title varchar NOT NULL
            PRIMARY KEY
            UNIQUE,
        parenttask varchar,
        maxxp bigint NOT NULL DEFAULT 0,
        CONSTRAINT fk_tasks_parenttask
            FOREIGN KEY (parenttask) REFERENCES tasks (title)
    );
CREATE TYPE check_status AS ENUM ('Start', 'Success', 'Failure');

CREATE TABLE checks
    (
        id serial PRIMARY KEY,
        peer varchar NOT NULL,
        task varchar NOT NULL,
        date date NOT NULL,
        CONSTRAINT fk_checks_peer
            FOREIGN KEY (peer) REFERENCES peers (nickname),
        CONSTRAINT fk_checks_task
            FOREIGN KEY (task) REFERENCES tasks (title)
    );

CREATE TABLE p2p
    (
        id serial
            PRIMARY KEY,
        "Check" serial,
        checkingpeer varchar NOT NULL,
        state check_status,
        time time without time zone,
        CONSTRAINT fk_p2p_check
            FOREIGN KEY ("Check") REFERENCES checks (id),
        CONSTRAINT fk_p2p_checkingpeer
            FOREIGN KEY (checkingpeer) REFERENCES peers (nickname)
    );

CREATE TABLE verter
    (
        id serial
            PRIMARY KEY,
        "Check" serial,
        state check_status,
        time time DEFAULT CURRENT_TIME,
        CONSTRAINT fk_verter_check
            FOREIGN KEY ("Check") REFERENCES checks (id)
    );

CREATE TABLE transferredpoints
    (
        id serial
            PRIMARY KEY,
        checkingpeer varchar NOT NULL,
        checkedpeer varchar NOT NULL,
        pointsamount bigint NOT NULL,
        CONSTRAINT fk_transferredpoints_checkingpeer
            FOREIGN KEY (checkingpeer) REFERENCES peers (nickname),
        CONSTRAINT fk_transferredpoints_checkedpeer
            FOREIGN KEY (checkedpeer) REFERENCES peers (nickname)
    );

CREATE TABLE friends
    (
        id serial
            PRIMARY KEY,
        peer1 varchar NOT NULL,
        peer2 varchar NOT NULL,
        CONSTRAINT fk_friends_peer1
            FOREIGN KEY (peer1) REFERENCES peers (nickname),
        CONSTRAINT fk_friends_peer2
            FOREIGN KEY (peer2) REFERENCES peers (nickname),
        CONSTRAINT un_peers_unique
            UNIQUE (peer1, peer2)
    );

CREATE TABLE recommendations
    (
        id serial
            PRIMARY KEY,
        peer varchar NOT NULL,
        recommendedpeer varchar NOT NULL,
        CONSTRAINT fk_recommendations_peer
            FOREIGN KEY (peer) REFERENCES peers (nickname),
        CONSTRAINT fk_recommendations_recommendedpeer
            FOREIGN KEY (recommendedpeer) REFERENCES peers (nickname),
        CONSTRAINT un_peers_recommendetions_unique
            UNIQUE (peer, recommendedpeer)
    );

CREATE TABLE xp
    (
        id serial
            PRIMARY KEY,
        "Check" serial,
        xpamount bigint NOT NULL
            CHECK ( xpamount > 0 ),
        CONSTRAINT fk_xp_check
            FOREIGN KEY ("Check") REFERENCES checks (id)
    );

CREATE TABLE timetracking
    (
        id serial
            PRIMARY KEY,
        peer varchar NOT NULL,
        date date NOT NULL
            CHECK ( date <= CURRENT_DATE ),
        time time NOT NULL
            CHECK ( time <= current_time AND Date = current_date OR Date <= current_date ),
        state int
            CHECK ( state IN (1, 2) ),
        CONSTRAINT fk_timetracking
            FOREIGN KEY (peer) REFERENCES peers (nickname)
    );

ALTER TABLE peers OWNER TO student;
ALTER TABLE tasks OWNER TO student;
ALTER TABLE checks OWNER TO student;
ALTER TABLE p2p OWNER TO student;
ALTER TABLE verter OWNER TO student;
ALTER TABLE transferredpoints OWNER TO student;
ALTER TABLE friends OWNER TO student;
ALTER TABLE recommendations OWNER TO student;
ALTER TABLE xp OWNER TO student;
ALTER TABLE timetracking OWNER TO student;

---------------------------------------------------------------------------------
------------------- Написать процедуру добавления P2P проверки ------------------
---------------------------------------------------------------------------------
-- проверяет выполнение задания
CREATE FUNCTION fn_check_done_task(in_peer VARCHAR, in_task VARCHAR) RETURNS boolean AS
$$
DECLARE
    p2p_    check_status;
    verter_ check_status;
BEGIN
    SELECT state
      INTO p2p_
      FROM p2p
               JOIN checks
               ON p2p."Check" = checks.id
     WHERE checks.peer = in_peer
       AND checks.task = in_task
     ORDER BY date DESC, time DESC
     LIMIT 1;
    SELECT state
      INTO verter_
      FROM verter
               JOIN checks
               ON verter."Check" = checks.id
     WHERE checks.peer = in_peer
       AND checks.task = in_task
     ORDER BY date DESC, time DESC
     LIMIT 1;
    IF (p2p_ = 'Success' AND verter_ <> 'Failure') THEN RETURN TRUE; ELSE RETURN FALSE; END IF;
END
$$ LANGUAGE plpgsql;

-- проверяет выполнение предыдущего задания
CREATE FUNCTION fn_check_prev_task(peer VARCHAR, task VARCHAR) RETURNS boolean AS
$$
DECLARE
    prev_task VARCHAR;
BEGIN
    SELECT parenttask INTO prev_task FROM tasks WHERE title = task LIMIT 1;
    IF prev_task IS NOT NULL THEN RETURN fn_check_done_task(peer, prev_task); ELSE RETURN TRUE; END IF;
END
$$ LANGUAGE plpgsql;

-- процедура добавления п2п проверки
CREATE PROCEDURE pr_add_p2p(in_checkedpeer VARCHAR, in_checkingpeer VARCHAR, in_task VARCHAR, in_state check_status,
                            in_time TIME) AS
$$
DECLARE
    check_id INTEGER;
BEGIN
    IF (fn_check_prev_task(in_checkedpeer, in_task) = TRUE) THEN
        IF in_state = 'Start' THEN
               INSERT INTO checks (id, peer, task, date)
               VALUES ((SELECT MAX(id) + 1 FROM checks), in_checkedpeer, in_task, CURRENT_DATE)
            RETURNING id::INTEGER INTO check_id;
        ELSEIF (in_state IN ('Success', 'Failure')) THEN
            SELECT checks.id
              INTO check_id
              FROM checks
                       JOIN p2p
                       ON checks.id = p2p."Check"
             WHERE peer = in_checkedpeer
               AND task = in_task
             GROUP BY checks.id
            HAVING COUNT(p2p."Check") = 1;
        END IF;

        IF check_id IS NOT NULL THEN
            INSERT INTO p2p (id, "Check", checkingpeer, state, time)
            VALUES ((SELECT MAX(id) + 1 FROM p2p), check_id, in_checkingpeer, in_state, in_time);
        END IF;
    END IF;
END
$$ LANGUAGE plpgsql;

ALTER PROCEDURE pr_add_p2p(in_checkedpeer VARCHAR, in_checkingpeer VARCHAR, in_task VARCHAR, in_state check_status, in_time TIME) OWNER TO student;
ALTER FUNCTION fn_check_done_task(in_peer VARCHAR, in_task VARCHAR) OWNER TO student;
ALTER FUNCTION fn_check_prev_task(peer VARCHAR, task VARCHAR) OWNER TO student;

---------------------------------------------------------------------------------
---------------- Написать процедуру добавления проверки Verter'ом ---------------
---------------------------------------------------------------------------------
CREATE PROCEDURE pr_add_verter(in_checkedpeer VARCHAR, in_task VARCHAR, in_state check_status, in_time TIME) AS
$$
DECLARE
    check_ INTEGER;
BEGIN
    SELECT checks.id
      INTO check_
      FROM checks
               JOIN p2p p
               ON checks.id = p."Check"
     WHERE task = in_task
       AND state = 'Success'
       AND peer = in_checkedpeer
     ORDER BY time DESC
     LIMIT 1;
    IF (check_ IS NOT NULL) THEN
        INSERT INTO verter (id, "Check", state, time)
        VALUES ((SELECT MAX(id) + 1 FROM verter), check_, in_state, in_time);
    END IF;
END;
$$ LANGUAGE plpgsql;

ALTER PROCEDURE pr_add_verter(in_checkedpeer VARCHAR, in_task VARCHAR, in_state check_status, in_time TIME) OWNER TO student;

---------------------------------------------------------------------------------
------------------ Написать триггер для P2P / TransferredPoints -----------------
---------------------------------------------------------------------------------
CREATE FUNCTION pr_after_start_in_p2p() RETURNS trigger AS
$$
DECLARE
    checkedpeer_   VARCHAR;
    transfered_id_ bigint;
BEGIN
    IF (new.state = 'Start') THEN
        SELECT peer
          INTO checkedpeer_
          FROM p2p
                   JOIN checks c
                   ON c.id = p2p."Check"
         WHERE p2p."Check" = new."Check"
         LIMIT 1;

        SELECT id
          INTO transfered_id_
          FROM transferredpoints
         WHERE checkingpeer = new.checkingpeer
           AND checkedpeer = checkedpeer_
         LIMIT 1;

        IF (transfered_id_ IS NULL) THEN
            INSERT INTO transferredpoints (id, checkingpeer, checkedpeer, pointsamount)
            VALUES ((SELECT COALESCE(MAX(id), 0) + 1 FROM transferredpoints), new.checkingpeer, checkedpeer_, 1);
        ELSE
            UPDATE transferredpoints
               SET pointsamount = pointsamount + 1
             WHERE checkingpeer = new.checkingpeer
               AND checkedpeer = checkedpeer_;
        END IF;
        RETURN new;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

ALTER FUNCTION pr_after_start_in_p2p() OWNER TO student;

-- триггер
CREATE TRIGGER tr_after_start_in_p2p
    AFTER INSERT
    ON p2p
    FOR EACH ROW
EXECUTE PROCEDURE pr_after_start_in_p2p();

---------------------------------------------------------------------------------
---------------------------- Написать триггер для XP ----------------------------
---------------------------------------------------------------------------------
CREATE FUNCTION pr_before_insert_in_xp() RETURNS trigger AS
$$
DECLARE
    max_xp_for_task_   boolean;
    success_for_check_ boolean;
BEGIN
    IF (new.xpamount <= (SELECT t.maxxp
                           FROM checks c
                                    JOIN tasks t
                                    ON c.task = t.title
                          WHERE c.id = new."Check")) THEN
        max_xp_for_task_ = TRUE;
    ELSE
        max_xp_for_task_ = FALSE;
    END IF;

    IF (EXISTS(SELECT *
                 FROM checks c
                          JOIN verter v
                          ON c.id = v."Check"
                          JOIN p2p p
                          ON c.id = p."Check"
                WHERE c.id = new."Check"
                  AND p.state = 'Success'
                  AND v.state = 'Success')) THEN
        success_for_check_ = TRUE;
    ELSE
        success_for_check_ = FALSE;
    END IF;

    IF (max_xp_for_task_ = TRUE AND success_for_check_ = TRUE) THEN RETURN new; END IF;
    RETURN old;
END;
$$ LANGUAGE plpgsql;

ALTER FUNCTION pr_before_insert_in_xp() OWNER TO student;

-- триггер
CREATE TRIGGER tr_before_insert_in_xp
    BEFORE INSERT
    ON xp
    FOR EACH ROW
EXECUTE PROCEDURE pr_before_insert_in_xp();

------------------------------------ 1 --------------------------------------------
-- 1) Написать функцию, возвращающую таблицу TransferredPoints в более человекочитаемом виде
CREATE OR REPLACE FUNCTION fn_get_transferred_points()
    RETURNS TABLE
                (
                    peer1 varchar,
                    peer2 varchar,
                    pointsamount bigint
                )
AS
$$
SELECT table1.checkingpeer AS peer1, table1.checkedpeer AS peer2,
       CASE WHEN (table1.pointsamount <= table2.pointsamount) THEN table1.pointsamount - table2.pointsamount
            WHEN (table1.pointsamount > table2.pointsamount) THEN table1.pointsamount - table2.pointsamount
            ELSE table1.pointsamount END
  FROM transferredpoints AS table1
           LEFT JOIN transferredpoints AS table2
           ON table1.checkingpeer = table2.checkedpeer AND table1.checkedpeer = table2.checkingpeer;
$$ LANGUAGE sql;

------------------------------------ 2 --------------------------------------------
-- 2) Написать функцию, которая возвращает таблицу вида: ник пользователя, название проверенного задания,
-- кол-во полученного XP
CREATE OR REPLACE FUNCTION fn_get_user_task_xp_summary()
    RETURNS TABLE
                (
                    peer varchar,
                    task varchar,
                    xp bigint
                )
AS
$$
  WITH cte AS (SELECT peer AS peer, task AS task, xpamount AS xp
                 FROM checks
                          JOIN xp x
                          ON checks.id = x."Check"
                ORDER BY peer, task)
SELECT *
  FROM cte
$$ LANGUAGE sql;

------------------------------------ 3 --------------------------------------------
-- 3) Написать функцию, определяющую пиров, которые не выходили из кампуса в течение всего дня
CREATE OR REPLACE FUNCTION fn_find_on_campus_peers_for_day(indate date DEFAULT CURRENT_DATE)
    RETURNS TABLE
                (
                    peer varchar
                )
AS
$$
  WITH cte AS (SELECT peer FROM timetracking WHERE date = indate GROUP BY peer HAVING COUNT(state) <= 2)
SELECT *
  FROM cte
$$ LANGUAGE sql;

------------------------------------ 4 --------------------------------------------
-- 4) Найти процент успешных и неуспешных проверок за всё время
CREATE OR REPLACE PROCEDURE pr_calculate_check_success_percentage(INOUT res refcursor) AS
$$
BEGIN
    OPEN res FOR SELECT ROUND(success * 100 / total, 2) AS successfulchecks,
                        100 - ROUND(success * 100 / total, 2) AS unsuccessfulchecks
                   FROM (SELECT COUNT(peer) AS total
                           FROM checks
                                    FULL JOIN verter v
                                    ON checks.id = v."Check"
                                    FULL JOIN p2p p
                                    ON checks.id = p."Check"
                          WHERE (v.state IN ('Success', 'Failure') OR v.state IS NULL)
                            AND p.state IN ('Success', 'Failure')) AS a,

                        (SELECT COUNT(peer) AS success
                           FROM checks
                                    FULL JOIN verter v
                                    ON checks.id = v."Check"
                                    FULL JOIN p2p p
                                    ON checks.id = p."Check"
                          WHERE (v.state = 'Success' OR v.state IS NULL)
                            AND p.state = 'Success') AS b,

                        (SELECT COUNT(peer) AS failure
                           FROM checks
                                    FULL JOIN verter v
                                    ON checks.id = v."Check"
                                    FULL JOIN p2p p
                                    ON checks.id = p."Check"
                          WHERE v.state IN ('Failure', NULL)
                             OR p.state = 'Failure') AS c;
END
$$ LANGUAGE plpgsql;

ALTER PROCEDURE pr_calculate_check_success_percentage(INOUT res refcursor) OWNER TO student;

------------------------------------ 5 --------------------------------------------
-- 5) Посчитать изменение в количестве пир поинтов каждого пира по таблице TransferredPoints
CREATE OR REPLACE PROCEDURE pr_calculate_peer_point_changes(INOUT res refcursor) AS
$$
BEGIN
    OPEN res FOR SELECT checkingpeer AS peer,
                        CASE WHEN give IS NULL THEN receive ELSE receive - give END AS pointschange
                   FROM (SELECT checkingpeer, SUM(pointsamount) AS receive
                           FROM transferredpoints
                          GROUP BY checkingpeer) AS d
                            FULL JOIN (SELECT checkedpeer, SUM(pointsamount) AS give
                                         FROM transferredpoints
                                        GROUP BY checkedpeer) AS b
                            ON checkedpeer = checkingpeer
                  ORDER BY pointschange DESC;
END
$$ LANGUAGE plpgsql;

ALTER PROCEDURE pr_calculate_peer_point_changes(INOUT res refcursor) OWNER TO student;

------------------------------------ 6 --------------------------------------------
-- 6) Посчитать изменение в количестве пир поинтов каждого пира по таблице, возвращаемой первой функцией из Part 3
CREATE OR REPLACE PROCEDURE pr_calculate_peer_point_changes_from_transfered_points(INOUT res refcursor) AS
$$
BEGIN
    OPEN res FOR WITH cte AS (SELECT *
                                FROM fn_get_transferred_points()
                               UNION
                              SELECT peer2, peer1, (-1) * pointsamount
                                FROM fn_get_transferred_points()
                               ORDER BY pointsamount DESC)
               SELECT peer1 AS peer, SUM(pointsamount) AS pointschange
                 FROM cte
                GROUP BY peer1
                ORDER BY pointschange DESC;
END
$$ LANGUAGE plpgsql;

ALTER PROCEDURE pr_calculate_peer_point_changes_from_transfered_points(INOUT res refcursor) OWNER TO student;

------------------------------------ 7 --------------------------------------------
-- 7) Определить самое часто проверяемое задание за каждый день
CREATE OR REPLACE PROCEDURE pr_find_most_frequently_checked_task_per_day(INOUT res refcursor) AS
$$
BEGIN
    OPEN res FOR WITH cte AS (SELECT task, date, COUNT(date) AS count FROM checks GROUP BY date, task ORDER BY date),
                      cte1 AS (SELECT date, MAX(count) AS max FROM cte GROUP BY date)
               SELECT cte1.date AS day, cte.task AS task
                 FROM cte1
                          JOIN cte
                          ON cte.date = cte1.date AND cte.count = cte1.max;
END
$$ LANGUAGE plpgsql;

ALTER PROCEDURE pr_find_most_frequently_checked_task_per_day(INOUT res refcursor) OWNER TO student;

------------------------------------ 8 --------------------------------------------
-- 8) Определить длительность последней P2P проверки
CREATE OR REPLACE PROCEDURE pr_calculate_last_p2p_check_duration(INOUT res refcursor) AS
$$
BEGIN
    OPEN res FOR WITH a AS (SELECT *
                              FROM checks
                                       JOIN p2p p2p2
                                       ON checks.id = p2p2."Check"),
                      b AS (SELECT MAX(date) AS maxdate FROM a WHERE state IN ('Success', 'Failure')),
                      c AS (SELECT MAX(a."time") AS maxtime
                              FROM a,
                                   b
                             WHERE a.date = b.maxdate),
                      d AS (SELECT a."Check" AS acheck
                              FROM a,
                                   c
                             WHERE time = c.maxtime),
                      e AS (SELECT "time" AS starttime
                              FROM p2p,
                                   d
                             WHERE "Check" = acheck
                               AND state = 'Start')
               SELECT (maxtime - starttime)::time AS "check duration"
                 FROM c,
                      e;
END
$$ LANGUAGE plpgsql;

ALTER PROCEDURE pr_calculate_last_p2p_check_duration(INOUT res refcursor) OWNER TO student;

------------------------------------ 9 --------------------------------------------
-- 9) Найти всех пиров, выполнивших весь заданный блок задач и дату завершения последнего задания
CREATE OR REPLACE PROCEDURE pr_find_peers_completed_block_of_tasks(INOUT res refcursor, block varchar) AS
$$
BEGIN
    OPEN res FOR SELECT peer, MAX(date) AS date
                   FROM (SELECT peer, task, date
                           FROM checks
                                    FULL JOIN verter v
                                    ON checks.id = v."Check"
                                    FULL JOIN p2p p
                                    ON checks.id = p."Check"
                          WHERE (v.state = 'Success' OR v.state IS NULL)
                            AND p.state = 'Success'
                            AND task LIKE '%' || block || '%') AS p
                  GROUP BY peer
                 HAVING COUNT(task) = (SELECT COUNT(title) FROM tasks WHERE title LIKE '%' || block || '%');
END
$$ LANGUAGE plpgsql;

ALTER PROCEDURE pr_find_peers_completed_block_of_tasks(INOUT res refcursor, block varchar) OWNER TO student;

-- 10) Определить, к какому пиру стоит идти на проверку каждому обучающемуся
-- Определять нужно исходя из рекомендаций друзей пира, т.е. нужно найти пира,
-- проверяться у которого рекомендует наибольшее число друзей.
-- Формат вывода: ник пира, ник найденного проверяющего
CREATE OR REPLACE PROCEDURE pr_assign_peer_for_check(INOUT res refcursor)
    LANGUAGE plpgsql AS
$$
BEGIN
    OPEN res FOR SELECT tmp.nickname AS peer, tmp.recommendedpeer AS recommendedpeer
                   FROM (SELECT p.nickname, r.recommendedpeer, COUNT(r.recommendedpeer) AS num
                           FROM peers AS p
                                    JOIN friends f
                                    ON p.nickname = f.peer1 OR p.nickname = f.peer2
                                    JOIN recommendations r
                                    ON (f.peer2 = r.peer AND f.peer2 != p.nickname) OR
                                       (f.peer1 = r.peer AND f.peer1 != p.nickname)
                          WHERE p.nickname != r.recommendedpeer
                          GROUP BY p.nickname, r.recommendedpeer) AS tmp
                  WHERE tmp.num = (SELECT MAX(tmp2.num)
                                     FROM (SELECT COUNT(r.recommendedpeer) AS num
                                             FROM peers AS p
                                                      JOIN friends f
                                                      ON p.nickname = f.peer1 OR p.nickname = f.peer2
                                                      JOIN recommendations r
                                                      ON (f.peer2 = r.peer AND f.peer2 != p.nickname) OR
                                                         (f.peer1 = r.peer AND f.peer1 != p.nickname)
                                            WHERE p.nickname != r.recommendedpeer
                                              AND tmp.nickname = p.nickname
                                            GROUP BY p.nickname, r.recommendedpeer) AS tmp2);
END;
$$;

ALTER PROCEDURE pr_assign_peer_for_check(INOUT res refcursor) OWNER TO student;

-- 11) Определить процент пиров, которые:
-- Приступили только к блоку 1
-- Приступили только к блоку 2
-- Приступили к обоим
-- Не приступили ни к одному
--
-- Пир считается приступившим к блоку, если он проходил
-- хоть одну проверку любого задания из этого блока (по таблице Checks)
-- Параметры процедуры: название блока 1, например SQL, название блока 2, например A.
-- Формат вывода: процент приступивших только к первому блоку, процент приступивших
-- только ко второму блоку, процент приступивших к обоим, процент не приступивших ни к одному
CREATE OR REPLACE PROCEDURE pr_calculate_block_progress_percentage(INOUT res refcursor, block1 varchar, block2 varchar)
    LANGUAGE plpgsql AS
$$
DECLARE
    totalpeers         numeric := (SELECT COUNT(*)
                                     FROM peers);
    startedbothblocks  numeric;
    startedblock1      numeric;
    startedblock2      numeric;
    didntstartanyblock numeric;
BEGIN
    startedbothblocks = (SELECT COUNT(tmp.peer)
                           FROM (SELECT peer
                                   FROM checks
                                  WHERE task SIMILAR TO block1 || '[0-9]' || '%'
                              INTERSECT
                                 SELECT peer
                                   FROM checks
                                  WHERE task SIMILAR TO block2 || '[0-9]' || '%') AS tmp);

    startedblock1 = ROUND(((SELECT COUNT(peer)
                              FROM (SELECT DISTINCT peer
                                      FROM checks
                                     WHERE task SIMILAR TO block1 || '[0-9]' || '%') AS tmp) - startedbothblocks) *
                          100 / totalpeers, 2);

    startedblock2 = ROUND(((SELECT COUNT(peer)
                              FROM (SELECT DISTINCT peer
                                      FROM checks
                                     WHERE task SIMILAR TO block2 || '[0-9]' || '%') AS tmp) - startedbothblocks) *
                          100 / totalpeers, 2);

    didntstartanyblock = ROUND((SELECT COUNT(*)
                                  FROM (SELECT *
                                          FROM checks
                                                   FULL JOIN peers p
                                                   ON checks.peer = p.nickname
                                         WHERE checks.peer IS NULL) AS tmp) * 100 / totalpeers, 2);

    startedbothblocks = ROUND(startedbothblocks * 100 / totalpeers, 2);
    OPEN res FOR SELECT startedblock1, startedblock2, startedbothblocks, didntstartanyblock;
END;
$$;

ALTER PROCEDURE pr_calculate_block_progress_percentage(INOUT res refcursor, block1 varchar, block2 varchar) OWNER TO student;

-- 12) Определить N пиров с наибольшим числом друзей
-- Параметры процедуры: количество пиров N.
-- Результат вывести отсортированным по кол-ву друзей.
-- Формат вывода: ник пира, количество друзей
CREATE OR REPLACE PROCEDURE pr_find_peers_with_most_friends(INOUT res refcursor, n bigint)
    LANGUAGE plpgsql AS
$$
BEGIN
    OPEN res FOR SELECT DISTINCT peer1 AS peer, COUNT(peer1) AS friendscount
                   FROM (SELECT f1.peer1, f1.peer2
                           FROM friends f1
                          UNION ALL
                         SELECT f2.peer2, f2.peer1
                           FROM friends f2) AS tmp
                  GROUP BY peer
                  ORDER BY 2 DESC
                  LIMIT n;
END;
$$;

ALTER PROCEDURE pr_find_peers_with_most_friends(INOUT res refcursor, n bigint) OWNER TO student;

-- 13) Определить процент пиров, которые когда-либо успешно проходили проверку в свой день рождения
-- Также определите процент пиров, которые хоть раз проваливали проверку в свой день рождения.
-- Формат вывода: процент успехов в день рождения, процент неуспехов в день рождения
CREATE OR REPLACE PROCEDURE pr_calculate_birthday_success_percentage(INOUT res refcursor)
    LANGUAGE plpgsql AS
$$
DECLARE
    totalchecks        numeric := (SELECT COUNT(*)
                                     FROM peers p
                                              JOIN checks c
                                              ON p.nickname = c.peer
                                              JOIN p2p
                                              ON c.id = p2p."Check"
                                    WHERE EXTRACT(DAY FROM p.birthday) = EXTRACT(DAY FROM c.date)
                                      AND EXTRACT(MONTH FROM p.birthday) = EXTRACT(MONTH FROM c.date)
                                      AND state = 'Start');
    successfulchecks   numeric := ROUND((SELECT COUNT(*)
                                           FROM peers p
                                                    JOIN checks c
                                                    ON p.nickname = c.peer
                                                    JOIN p2p
                                                    ON c.id = p2p."Check"
                                          WHERE EXTRACT(DAY FROM p.birthday) = EXTRACT(DAY FROM c.date)
                                            AND EXTRACT(MONTH FROM p.birthday) = EXTRACT(MONTH FROM c.date)
                                            AND state = 'Success') * 100 / totalchecks, 2);
    unsuccessfulchecks numeric := ROUND((SELECT COUNT(*)
                                           FROM peers p
                                                    JOIN checks c
                                                    ON p.nickname = c.peer
                                                    JOIN p2p
                                                    ON c.id = p2p."Check"
                                          WHERE EXTRACT(DAY FROM p.birthday) = EXTRACT(DAY FROM c.date)
                                            AND EXTRACT(MONTH FROM p.birthday) = EXTRACT(MONTH FROM c.date)
                                            AND state = 'Failure') * 100 / totalchecks, 2);
BEGIN
    OPEN res FOR SELECT successfulchecks, unsuccessfulchecks;
END;
$$;

ALTER PROCEDURE pr_calculate_birthday_success_percentage(INOUT res refcursor) OWNER TO student;

-- 14) Определить кол-во XP, полученное в сумме каждым пиром
-- Если одна задача выполнена несколько раз, полученное за нее кол-во XP равно максимальному за эту задачу.
-- Результат вывести отсортированным по кол-ву XP.
-- Формат вывода: ник пира, количество XP
CREATE OR REPLACE PROCEDURE pr_calculate_all_xp_by_peers(INOUT res refcursor)
    LANGUAGE plpgsql AS
$$
BEGIN
    OPEN res FOR SELECT DISTINCT p.nickname AS peer, SUM(t.maxxp) AS xp
                   FROM peers p
                            JOIN checks c
                            ON p.nickname = c.peer
                            JOIN p2p
                            ON c.id = p2p."Check" AND p2p.state = 'Success'
                            JOIN tasks t
                            ON c.task = t.title
                            LEFT JOIN verter v
                            ON c.id = v."Check" AND (v.state = 'Success' OR v.state IS NULL)
                  GROUP BY p.nickname
                  ORDER BY xp DESC;
END;
$$;

ALTER PROCEDURE pr_calculate_all_xp_by_peers(INOUT res refcursor) OWNER TO student;

-- 15) Определить всех пиров, которые сдали заданные задания 1 и 2, но не сдали задание 3
-- Параметры процедуры: названия заданий 1, 2 и 3.
-- Формат вывода: список пиров
CREATE OR REPLACE PROCEDURE pr_find_peers_with_specific_task_completion(INOUT res refcursor, first varchar, second varchar, third varchar)
    LANGUAGE plpgsql AS
$$
BEGIN
    OPEN res FOR SELECT c.peer
                   FROM checks c
                            JOIN p2p
                            ON c.id = p2p."Check" AND p2p.state = 'Success' AND c.task = first
              INTERSECT
                 SELECT c.peer
                   FROM checks c
                            JOIN p2p
                            ON c.id = p2p."Check" AND p2p.state = 'Success' AND c.task = second
              INTERSECT
                 SELECT c.peer
                   FROM checks c
                            FULL JOIN p2p
                            ON c.id = p2p."Check" AND p2p.state IS NULL AND c.task = third;
END;
$$;

ALTER PROCEDURE pr_find_peers_with_specific_task_completion(INOUT res refcursor, first varchar, second varchar, third varchar) OWNER TO student;

-- 16) Используя рекурсивное обобщенное табличное выражение, для каждой задачи вывести кол-во предшествующих ей задач
-- То есть сколько задач нужно выполнить, исходя из условий входа, чтобы получить доступ к текущей.
-- Формат вывода: название задачи, количество предшествующих
CREATE OR REPLACE PROCEDURE pr_count_previous_tasks(INOUT res refcursor)
    LANGUAGE plpgsql AS
$$
BEGIN
    OPEN res FOR WITH RECURSIVE previous_task(title, parenttask, count) AS (SELECT title, parenttask, 0
                                                                              FROM tasks
                                                                             WHERE parenttask IS NULL
                                                                             UNION ALL
                                                                            SELECT t.title, t.parenttask, count + 1
                                                                              FROM previous_task pt,
                                                                                   tasks t
                                                                             WHERE pt.title = t.parenttask)
               SELECT title AS task, count AS prevcount
                 FROM previous_task;
END;
$$;

ALTER PROCEDURE pr_count_previous_tasks(INOUT res refcursor) OWNER TO student;

-- 17) Найти "удачные" для проверок дни. День считается "удачным",
-- если в нем есть хотя бы N идущих подряд успешных проверки
-- Параметры процедуры: количество идущих подряд успешных проверок N.
-- Временем проверки считать время начала P2P этапа.
-- Под идущими подряд успешными проверками подразумеваются успешные проверки, между которыми нет неуспешных.
-- При этом кол-во опыта за каждую из этих проверок должно быть не меньше 80% от максимального.
-- Формат вывода: список дней
CREATE OR REPLACE PROCEDURE pr_find_good_days(INOUT res refcursor, n bigint)
    LANGUAGE plpgsql AS
$$
BEGIN
    OPEN res FOR SELECT DISTINCT date AS lucky_days
                   FROM (SELECT date, state, ROW_NUMBER() OVER (PARTITION BY date, x ORDER BY date, state) AS k
                           FROM (SELECT date, state, time, xpamount, maxxp,
                                        COUNT(CASE WHEN state != 'Success' THEN 1 END)
                                        OVER (PARTITION BY date ORDER BY date, time) AS x
                                   FROM checks
                                            JOIN p2p
                                            ON checks.id = p2p."Check"
                                            FULL JOIN xp
                                            ON checks.id = xp."Check"
                                            FULL JOIN tasks t
                                            ON checks.task = t.title
                                  WHERE p2p.state != 'Start') AS tmp1
                          WHERE xpamount * 100 / maxxp >= 80) AS tmp2
                  WHERE state != 'Failure'
                    AND k >= n;
END;
$$;

ALTER PROCEDURE pr_find_good_days(INOUT res refcursor, n bigint) OWNER TO student;

-- 18) Определить пира с наибольшим числом выполненных заданий
-- Формат вывода: ник пира, число выполненных заданий
CREATE OR REPLACE PROCEDURE pr_find_peer_with_most_completed_tasks(INOUT res refcursor)
    LANGUAGE plpgsql AS
$$
BEGIN
    OPEN res FOR SELECT peer, COUNT(peer) AS number
                   FROM checks
                            JOIN xp x
                            ON checks.id = x."Check"
                  GROUP BY peer
                  ORDER BY number DESC
                  LIMIT 1;
END;
$$;

ALTER PROCEDURE pr_find_peer_with_most_completed_tasks(INOUT res refcursor) OWNER TO student;

-- 19) Определить пира с наибольшим количеством XP
-- Формат вывода: ник пира, количество XP
CREATE OR REPLACE PROCEDURE pr_find_peer_with_most_xp(INOUT res refcursor)
    LANGUAGE plpgsql AS
$$
BEGIN
    OPEN res FOR SELECT peer, SUM(xpamount) AS xp
                   FROM checks
                            JOIN xp x
                            ON checks.id = x."Check"
                  GROUP BY peer
                  ORDER BY xp DESC
                  LIMIT 1;
END;
$$;

ALTER PROCEDURE pr_find_peer_with_most_xp(INOUT res refcursor) OWNER TO student;

------------------------------------ 20 --------------------------------------------
-- 20) Определить пира, который провел сегодня в кампусе больше всего времени
CREATE OR REPLACE PROCEDURE pr_find_peer_with_most_time_on_campus_today(INOUT res refcursor) AS
$$
BEGIN
    OPEN res FOR SELECT peer
                   FROM (WITH cte AS (SELECT peer, time AS in_time, state, ROW_NUMBER() OVER () AS id
                                        FROM timetracking
                                       WHERE date = CURRENT_DATE
                                         AND state = 1
                                       GROUP BY peer, time, state),
                              cte1 AS (SELECT peer, time AS out_time, state, ROW_NUMBER() OVER () AS id
                                         FROM timetracking
                                        WHERE date = CURRENT_DATE
                                          AND state = 2
                                        GROUP BY peer, time, state)
                       SELECT cte.peer AS peer, SUM(out_time - in_time)::time AS time
                         FROM cte1
                                  JOIN cte
                                  ON cte1.id = cte.id
                        GROUP BY cte.peer) AS a
                  ORDER BY time DESC
                  LIMIT 1;
END
$$ LANGUAGE plpgsql;

ALTER PROCEDURE pr_find_peer_with_most_time_on_campus_today(INOUT res refcursor) OWNER TO student;

------------------------------------ 21 --------------------------------------------
-- 21) Определить пиров, приходивших раньше заданного времени не менее N раз за всё время
CREATE OR REPLACE PROCEDURE pr_find_peers_who_came_before_time_N_times(INOUT res refcursor, this_time time, count bigint) AS
$$
BEGIN
    OPEN res FOR SELECT peer
                   FROM (SELECT peer, date
                           FROM timetracking
                          WHERE time < this_time AND state = 1
                          GROUP BY peer, date) AS a
                  GROUP BY peer
                 HAVING COUNT(date) >= count
                  ORDER BY peer;
END
$$ LANGUAGE plpgsql;

ALTER PROCEDURE pr_find_peers_who_came_before_time_N_times(INOUT res refcursor, this_time time, count bigint) OWNER TO student;

------------------------------------ 22 --------------------------------------------
-- 22) Определить пиров, выходивших за последние N дней из кампуса больше M раз
CREATE OR REPLACE PROCEDURE pr_find_peers_with_off_campus_frequency(INOUT res refcursor, n_days integer, m_times integer) AS
$$
BEGIN
    OPEN res FOR SELECT peer
                   FROM (SELECT peer, date, COUNT(*) AS count_
                           FROM timetracking
                          WHERE state = 2
                            AND date >= (NOW()::date - n_days)
                          GROUP BY peer, date) AS a
                  GROUP BY peer
                 HAVING SUM(count_) > m_times
                  ORDER BY peer;
END
$$ LANGUAGE plpgsql;

ALTER PROCEDURE pr_find_peers_with_off_campus_frequency(INOUT res refcursor, n_days integer, m_times integer) OWNER TO student;

------------------------------------ 23 --------------------------------------------
-- 23) Определить пира, который пришел сегодня последним
CREATE OR REPLACE PROCEDURE pr_find_last_arriving_peer_today(INOUT res refcursor) AS
$$
BEGIN
    OPEN res FOR SELECT peer
                   FROM (SELECT peer, MIN(time) AS time
                           FROM (SELECT peer, time FROM timetracking WHERE state = 1 AND date = CURRENT_DATE) AS a
                          GROUP BY peer) AS b
                  ORDER BY b.time DESC
                  LIMIT 1;
END
$$ LANGUAGE plpgsql;

ALTER PROCEDURE pr_find_last_arriving_peer_today(INOUT res refcursor) OWNER TO student;

------------------------------------ 24 --------------------------------------------
-- 24) Определить пиров, которые выходили вчера из кампуса больше чем на N минут
CREATE OR REPLACE PROCEDURE pr_find_peers_with_long_off_campus_time_yesterday(INOUT res refcursor, n_minutes bigint) AS
$$
BEGIN
    OPEN res FOR WITH table_in AS (SELECT ROW_NUMBER() OVER () AS id, peer, time AS in_time, state
                                     FROM timetracking
                                    WHERE date = CURRENT_DATE - 1
                                      AND state = 1
                                    GROUP BY peer, time, state
                                   OFFSET 1 ROWS),
                      table_out AS (SELECT ROW_NUMBER() OVER () AS id, peer, time AS out_time, state
                                      FROM timetracking
                                     WHERE date = CURRENT_DATE - 1
                                       AND state = 2
                                     GROUP BY peer, time, state
                                     ORDER BY id DESC
                                    OFFSET 1 ROWS)

               SELECT tmp.peer
                 FROM (SELECT table_in.peer, SUM(in_time - out_time)::time AS sum
                         FROM table_in
                                  JOIN table_out
                                  ON table_in.id - 1 = table_out.id AND table_in.peer = table_out.peer
                        GROUP BY table_in.peer) AS tmp
                WHERE EXTRACT(HOURS FROM sum) * 60 * 60 + EXTRACT(MINUTES FROM sum) * 60 + EXTRACT(SECONDS FROM sum) >
                      n_minutes * 60;
END
$$ LANGUAGE plpgsql;

ALTER PROCEDURE pr_find_peers_with_long_off_campus_time_yesterday(INOUT res refcursor, n_minutes bigint) OWNER TO student;

-- 25) Определить для каждого месяца процент ранних входов
-- Для каждого месяца посчитать, сколько раз люди, родившиеся в этот месяц, приходили в кампус
-- за всё время (будем называть это общим числом входов).
-- Для каждого месяца посчитать, сколько раз люди, родившиеся в этот месяц, приходили в кампус
-- раньше 12:00 за всё время (будем называть это числом ранних входов).
-- Для каждого месяца посчитать процент ранних входов в кампус относительно общего числа входов.
-- Формат вывода: месяц, процент ранних входов
CREATE OR REPLACE PROCEDURE pr_calculate_monthly_early_entry_percentage(INOUT res refcursor)
    LANGUAGE plpgsql AS
$$
BEGIN
    OPEN res FOR WITH months AS (SELECT ROW_NUMBER() OVER () AS num, TO_CHAR(gs, 'Month') AS month
                                   FROM (SELECT generate_series AS gs
                                           FROM GENERATE_SERIES('2022-01-01', '2022-12-31', INTERVAL '1 month')) AS s)

               SELECT month,
                      COALESCE((SELECT COUNT(*) * 100 / NULLIF((SELECT COUNT(*)
                                                                  FROM peers p1
                                                                           JOIN timetracking t1
                                                                           ON p1.nickname = t1.peer
                                                                 WHERE EXTRACT(MONTH FROM p1.birthday) = EXTRACT(MONTH FROM t1.date)
                                                                   AND t1.state = 1
                                                                   AND num = EXTRACT(MONTH FROM t1.date)), 0)
                                  FROM peers p
                                           JOIN timetracking t
                                           ON p.nickname = t.peer
                                 WHERE EXTRACT(MONTH FROM p.birthday) = EXTRACT(MONTH FROM t.date)
                                   AND num = EXTRACT(MONTH FROM t.date)
                                   AND t.state = 1
                                   AND EXTRACT(HOURS FROM t.time) < 12), 0) AS earlyentries
                 FROM months;
END;
$$;

ALTER PROCEDURE pr_calculate_monthly_early_entry_percentage(INOUT res refcursor) OWNER TO student;
