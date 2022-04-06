-- CREATE 0 USER (Initial System Administrator)
-- DEFAULT PASSWORD adminADMIN
INSERT INTO `vault`.`users` (`id`, `name`, `username`, `email`, `ciphertext`, `creator`)
       VALUES               (0, 'System Administrator', 'admin', 'admin@objectvault', UNHEX('a571513abb69a0de867f8163f042ee5f4aacc580dde8906ffd494800e1e87fc053dc10cb55a223e152c6fef8b36ca10c18eb43b75686863277ee5516'), 0);

-- CREATE 0 ORGANIZATION (System Management Organization)
INSERT INTO `vault`.`orgs` (`id`, `orgname`, `name`, `creator`)
       VALUES              (0, 'system', 'System Organization', 0);
-- TODO: SET 0 Organization Object Including Default Password Policy

-- GLOBAL User Registry : Register 0 User
INSERT INTO `vault`.`registry_users` (`id_user`, `name`, `username`, `email`, `state`, `ciphertext`)
       VALUES                        (CONV('1000000000000', 16, 10), 'System Administrator', 'admin', 'admin@objectvault', 4096, UNHEX('a571513abb69a0de867f8163f042ee5f4aacc580dde8906ffd494800e1e87fc053dc10cb55a223e152c6fef8b36ca10c18eb43b75686863277ee5516'));

-- GLOBAL Organization Registry : Register 0 Org - State 4096 (SYSTEM Organization)
INSERT INTO `vault`.`registry_orgs` (`id_org`, `orgname`, `name`, `state`)
       VALUES                       (CONV('2000000000000', 16, 10), 'system', 'System Organization', 4096);

-- ORGANIZATION User Registry : Associate 0 User with 0 Org - All Roles - State 4096 (SYSTEM ADMIN)
INSERT INTO `vault`.`registry_object_users` (`id_object`, `id_user`, `username`, `state`, `roles`)
       VALUES                               (CONV('2000000000000', 16, 10), CONV('1000000000000', 16, 10), 'admin', 4096, '16908287,16973823,17039359,33685503,33751039,33816575,33882111,33947647');

-- USER Objects Registry : Associate 0 User wih 0 Org
INSERT INTO `vault`.`registry_user_objects` (`id_user`, `type`, `id_object`, `alias`, `favorite`)
       VALUES                               (CONV('1000000000000', 16, 10), 2, CONV('2000000000000', 16, 10), 'system', 1);

-- Basic Templates
INSERT INTO `vault`.`templates` (`name`, `version`, `title`, `description`, `model`)
       VALUES ('note', '1', 'Note', 'Note Template', '{"template":{"name":"note","version":1},"display":{"title":"Note","groups":["detail"],"layout":"column"},"groups":{"detail":{"layout":"row","fields":["note"]}},"fields":{"note":{"type":"text","label":"Note","validations":{"required":true,"max-length":2048}}}}');
