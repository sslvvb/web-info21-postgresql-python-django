\c info21_db;

INSERT INTO peers
  VALUES
    ('aboba', '2000-01-01'),
    ('amogus', '2000-01-01'),
    ('impostor', '2002-05-06'),
    ('pepega', '1999-02-15'),
    ('nyancat', '2001-03-04');

INSERT INTO tasks
  VALUES
    ('C2_SimpleBash', NULL, 250),
    ('C3_s21_string', 'C2_SimpleBash', 500),
    ('C4_s21_math', 'C2_SimpleBash', 300),
    ('DO1_Linux', 'C3_s21_string', 300),
    ('DO2_Linux_Network', 'DO1_Linux', 250),
    ('CPP1_s21_matrix+', 'C3_s21_string', 300),
    ('CPP2_s21_containers', 'CPP1_s21_matrix+', 350);

INSERT INTO friends (peer1, peer2)
  VALUES
    ('aboba', 'amogus'),
    ('amogus', 'impostor'),
    ('impostor', 'aboba'),
    ('impostor', 'nyancat'),
    ('aboba', 'nyancat');

INSERT INTO recommendations (peer, recommendedpeer)
  VALUES
    ('aboba', 'impostor'),
    ('aboba', 'pepega'),
    ('nyancat', 'impostor'),
    ('impostor', 'amogus'),
    ('pepega', 'impostor');

INSERT INTO checks (peer, task, date)
  VALUES
    ('aboba', 'C2_SimpleBash', '2022-01-01'),
    ('aboba', 'C2_SimpleBash', '2022-01-02'),
    ('amogus', 'C2_SimpleBash', '2022-01-02'),
    ('aboba', 'C2_SimpleBash', '2022-01-03'),
    ('impostor', 'C2_SimpleBash', '2022-01-04'),
    ('impostor', 'C3_s21_string', '2022-01-07'),
    ('amogus', 'C3_s21_string', '2022-01-09'),
    ('impostor', 'C4_s21_math', '2022-01-10'),
    ('amogus', 'DO1_Linux', '2022-01-12'),
    ('amogus', 'CPP1_s21_matrix+', '2022-01-17'),
    ('aboba', 'C2_SimpleBash', '2023-01-01'),
    ('aboba', 'C2_SimpleBash', '2023-01-01'),
    ('aboba', 'C2_SimpleBash', '2023-01-01'),
    ('aboba', 'C2_SimpleBash', '2023-01-01'),
    ('aboba', 'C2_SimpleBash', '2023-01-01');

INSERT INTO p2p ("Check", checkingpeer, state, time)
  VALUES
    (1, 'amogus', 'Start', '12:00:00'),
    (1, 'amogus', 'Failure', '12:30:00'),
    (2, 'pepega', 'Start', '12:10:00'),
    (3, 'impostor', 'Start', '12:13:00'),
    (2, 'pepega', 'Success', '12:45:00'),
    (3, 'impostor', 'Success', '13:04:00'),
    (4, 'nyancat', 'Start', '12:00:00'),
    (4, 'nyancat', 'Success', '12:35:00'),
    (5, 'aboba', 'Start', '12:07:00'),
    (5, 'aboba', 'Success', '12:28:00'),
    (6, 'amogus', 'Start', '13:02:00'),
    (6, 'amogus', 'Success', '13:57:00'),
    (7, 'impostor', 'Start', '12:00:00'),
    (7, 'impostor', 'Success', '12:35:00'),
    (8, 'pepega', 'Start', '12:00:00'),
    (8, 'pepega', 'Success', '12:24:00'),
    (9, 'nyancat', 'Start', '12:15:00'),
    (9, 'nyancat', 'Failure', '12:42:00'),
    (10, 'aboba', 'Start', '11:45:00'),
    (10, 'aboba', 'Success', '12:16:00'),
    (11, 'amogus', 'Start', '12:00:00'),
    (11, 'amogus', 'Success', '13:00:00'),
    (12, 'amogus', 'Start', '14:00:00'),
    (12, 'amogus', 'Success', '15:00:00'),
    (13, 'amogus', 'Start', '16:00:00'),
    (13, 'amogus', 'Success', '17:00:00'),
    (14, 'amogus', 'Start', '19:00:00'),
    (14, 'amogus', 'Failure', '20:00:00'),
    (15, 'amogus', 'Start', '21:00:00'),
    (15, 'amogus', 'Success', '22:00:00');

INSERT INTO verter ("Check", state, time)
  VALUES
    (2, 'Start', '12:45:00'),
    (2, 'Failure', '12:48:00'),
    (3, 'Start', '13:05:00'),
    (3, 'Success', '13:09:00'),
    (4, 'Start', '12:37:00'),
    (4, 'Success', '12:42:00'),
    (5, 'Start', '12:32:00'),
    (5, 'Success', '12:37:00'),
    (6, 'Start', '13:59:00'),
    (6, 'Success', '14:12:00'),
    (7, 'Start', '12:35:00'),
    (7, 'Success', '12:41:00'),
    (8, 'Start', '12:25:00'),
    (8, 'Failure', '12:37:00'),
    (11, 'Start', '13:00:00'),
    (11, 'Success', '14:00:00'),
    (12, 'Start', '15:00:00'),
    (12, 'Success', '16:00:00'),
    (13, 'Start', '17:00:00'),
    (13, 'Success', '18:00:00'),
    (15, 'Start', '22:00:00'),
    (15, 'Success', '23:00:00');

INSERT INTO xp ("Check", xpamount)
  VALUES
    (3, 225),
    (4, 250),
    (5, 213),
    (6, 250),
    (7, 475),
    (10, 300),
    (11, 230),
    (12, 240),
    (13, 250),
    (15, 250);

INSERT INTO timetracking (peer, date, time, state)
  VALUES
    ('aboba', '2022-01-01', '09:00:00', 1),
    ('impostor', '2022-01-01', '09:30:00', 1),
    ('impostor', '2022-01-01', '11:00:00', 2),
    ('amogus', '2022-01-01', '14:15:00', 1),
    ('aboba', '2022-01-01', '16:00:00', 2),
    ('amogus', '2022-01-01', '16:30:00', 2),
    ('amogus', '2022-01-01', '17:00:00', 1),
    ('amogus', '2022-01-01', '18:10:00', 2),
    ('aboba', '2022-01-02', '09:30:00', 1),
    ('aboba', '2022-01-02', '10:05:00', 2),
    ('aboba', '2022-01-02', '11:15:00', 1),
    ('aboba', '2022-01-02', '12:40:00', 2),
    ('impostor', '2022-02-01', '10:00:00', 1),
    ('pepega', '2022-02-01', '10:15:00', 1),
    ('impostor', '2022-02-01', '10:45:00', 2),
    ('impostor', '2022-02-01', '11:05:00', 1),
    ('impostor', '2022-02-01', '11:45:00', 2),
    ('impostor', '2022-02-01', '12:10:00', 1),
    ('impostor', '2022-02-01', '16:10:00', 2),
    ('pepega', '2022-02-01', '17:00:00', 2),
    ('aboba', CURRENT_DATE - 1, '13:00', 1),
    ('aboba', CURRENT_DATE - 1, '14:00', 2),
    ('amogus', CURRENT_DATE - 1, '14:00', 1),
    ('aboba', CURRENT_DATE - 1, '14:10', 1),
    ('aboba', CURRENT_DATE - 1, '15:00', 2),
    ('amogus', CURRENT_DATE - 1, '15:00', 2),
    ('aboba', CURRENT_DATE - 1, '15:10', 1),
    ('amogus', CURRENT_DATE - 1, '15:15', 1),
    ('aboba', CURRENT_DATE - 1, '16:00', 2),
    ('amogus', CURRENT_DATE - 1, '16:00', 2),
    ('aboba', CURRENT_DATE, '10:00:00', 1),
    ('amogus', CURRENT_DATE, '10:30:00', 1),
    ('aboba', CURRENT_DATE, '11:00:00', 2),
    ('aboba', CURRENT_DATE, '12:00:00', 1),
    ('amogus', CURRENT_DATE, '12:00:00', 2),
    ('aboba', CURRENT_DATE, '13:00:00', 2);
