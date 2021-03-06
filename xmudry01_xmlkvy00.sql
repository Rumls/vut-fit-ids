------------------ IDS 2020 --------------------
-- xmudry01
-- xmlkvy00

-------------- DROP TABLE ----------------------
DROP TABLE Rasa CASCADE CONSTRAINTS;
DROP TABLE Macka CASCADE CONSTRAINTS;
DROP TABLE Admin CASCADE CONSTRAINTS;
DROP TABLE Zivot CASCADE CONSTRAINTS;
DROP TABLE Nazov CASCADE CONSTRAINTS;
DROP TABLE Hostitel CASCADE CONSTRAINTS;
DROP TABLE Teritorium CASCADE CONSTRAINTS;
DROP TABLE Vec CASCADE CONSTRAINTS;
DROP TABLE Spravuje CASCADE CONSTRAINTS;
DROP TABLE Byva CASCADE CONSTRAINTS;
DROP TABLE JePozicane CASCADE CONSTRAINTS;
DROP TABLE JePrivlastnene CASCADE CONSTRAINTS;

-------------- CREATE TABLE ---------------------
CREATE TABLE Rasa (
  nazov VARCHAR2(32) NOT NULL PRIMARY KEY,
  farba_oci VARCHAR2(32),
  povod VARCHAR2(128),
  max_dlzka_tesakov int,
  dlzka_chvosta int
);

CREATE TABLE Macka (
  id int GENERATED BY DEFAULT AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL PRIMARY KEY,
  meno VARCHAR2(32) NOT NULL,
  vzor_koze VARCHAR2(32),
  farba_srsti VARCHAR2(32),
  hmotnost int,

  rasa,
  FOREIGN KEY (rasa) REFERENCES Rasa(nazov)
);

CREATE TABLE Admin (
  id int GENERATED BY DEFAULT AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL PRIMARY KEY,
  Macka_id NOT NULL UNIQUE,
  FOREIGN KEY (Macka_id) REFERENCES Macka(id)
);

CREATE TABLE Zivot ( -- weak --
  id int GENERATED BY DEFAULT AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL PRIMARY KEY,
  Macka_id NOT NULL,

  cislo_zivota int,
  miesto_narodenia VARCHAR2(128),
  miesto_umrtia VARCHAR2(128),
  sposob_smrti VARCHAR2(256),

  FOREIGN KEY (Macka_id) REFERENCES Macka(id)
);

CREATE or REPLACE TYPE rasy IS VARRAY(3) of VARCHAR2(32);

CREATE TABLE Hostitel (
  id int GENERATED BY DEFAULT AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL PRIMARY KEY,
  meno VARCHAR2(32) NOT NULL,
  datum_narodenia DATE,
  pohlavie VARCHAR2(32),
  bydlisko VARCHAR2(128),
  pref_rasy rasy
);

CREATE TABLE Nazov (
  id int GENERATED BY DEFAULT AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL PRIMARY KEY,

  Macka_id NOT NULL,
  Hostitel_id NOT NULL,
  meno_od_hostitela VARCHAR2(32) NOT NULL,

  FOREIGN KEY (Macka_id) REFERENCES Macka(id),
  FOREIGN KEY (Hostitel_id) REFERENCES Hostitel(id)
);

CREATE TABLE Teritorium (
  id int GENERATED BY DEFAULT AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL PRIMARY KEY,
  typ_teritoria VARCHAR2(32) NOT NULL,
  kapacita int NOT NULL
);

CREATE TABLE Vec (
  id int GENERATED BY DEFAULT AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL PRIMARY KEY,
  typ_veci VARCHAR2(32) NOT NULL,
  kvantita int
);

---------------------------------------------

CREATE TABLE Spravuje (
  id int GENERATED BY DEFAULT AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL PRIMARY KEY,
  Teritorium_id NOT NULL,
  Hostitel_id NOT NULL,
  FOREIGN KEY (Teritorium_id) REFERENCES Teritorium(id),
  FOREIGN KEY (Hostitel_id) REFERENCES Hostitel(id)
);

CREATE TABLE Byva (
  zabyvanie DATE,
  odchod DATE,

  Macka_id NOT NULL,
  Teritorium_id NOT NULL,

  FOREIGN KEY (Macka_id) REFERENCES Macka(id),
  FOREIGN KEY (Teritorium_id) REFERENCES Teritorium(id)
);

CREATE TABLE JePozicane (
  pozicane DATE,
  vratene DATE,

  id int GENERATED BY DEFAULT AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL PRIMARY KEY,

  Vec_id NOT NULL,
  Hostitel_id NOT NULL,

  FOREIGN KEY (Vec_id) REFERENCES Vec(id),
  FOREIGN KEY (Hostitel_id) REFERENCES Hostitel(id)
);

CREATE TABLE JePrivlastnene (
  privlastnenie DATE,
  odhodenie DATE,

  id int GENERATED BY DEFAULT AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL PRIMARY KEY,

  Vec_id NOT NULL,
  Macka_id NOT NULL,

  FOREIGN KEY (Vec_id) REFERENCES Vec(id),
  FOREIGN KEY (Macka_id) REFERENCES Macka(id)
);

------------------ PROCEDURY ------------------
-- Procedura dostane ako argument nazov teritoria a do dbms_output vetou vypise pocet maciek, ktore sa momentalne v nom nachadzaju
CREATE OR REPLACE PROCEDURE pocet_mackiek_v_teritoriu(typ_teritoria IN VARCHAR2)
AS CURSOR byvanie IS
  SELECT *
  FROM Teritorium T, Byva B
  WHERE T.id = B.Teritorium_id;
  pocet NUMBER;
  macka VARCHAR2(10);
  BEGIN
    pocet := 0;
    FOR riadok IN byvanie LOOP
      IF riadok.typ_teritoria = typ_teritoria AND (riadok.odchod IS NULL OR riadok.odchod > sysdate) THEN
        pocet := pocet + 1;
      END IF;
    END LOOP;
    IF pocet = 0 THEN
        dbms_output.put_line('V terit??riu "' || typ_teritoria || '" sa moment??lne nenach??dza ??iadna ma??ka.');
    ELSE
        IF pocet = 1 THEN
            macka := ' ma??ka.';
        ELSIF pocet > 1 AND pocet < 5 THEN
            macka := ' ma??ky.';
        ELSE
            macka := ' ma??iek.';
        END IF;
        dbms_output.put_line('V terit??riu "' || typ_teritoria || '" sa moment??lne nach??dza ' || pocet || macka);
    END IF;
    EXCEPTION
        WHEN OTHERS THEN
          RAISE_APPLICATION_ERROR(-20000, 'Neo??ak??van?? chyba proced??ry.');
  END;

-- Procedura, ktora kontroluje unikatnost zivotov
CREATE OR REPLACE PROCEDURE zivot_unique_check(macka_id IN int, zivot_no IN int)
AS CURSOR macky_zivoty IS
  SELECT Z.Macka_id, Z.cislo_zivota
  FROM Macka M, Zivot Z
  WHERE M.id = Z.Macka_id;
  BEGIN
    FOR ziv IN macky_zivoty LOOP
      IF macka_id = ziv.Macka_id AND zivot_no = ziv.cislo_zivota THEN
        Raise_Application_Error(-20011, 'U?? existuje ??ivot s dan??m poradov??m ????slom.');
      END IF;
    END LOOP;
    dbms_output.put_line('??ivot ????slo ' || zivot_no || ' pre ma??ku s ID ' || macka_id || ' je unik??tny, v??etko je v poriadku.');
  END;

------------------ TRIGGERS -------------------
-- Trigger na validaciu poctu zivotov macky a kontrolu ich vlozeneho poctu.
CREATE OR REPLACE TRIGGER trigger_max_zivotov
	BEFORE INSERT OR UPDATE ON Zivot
	FOR EACH ROW
BEGIN
    IF :new.cislo_zivota < 1 AND :new.cislo_zivota > 9 THEN
        Raise_Application_Error(-20010, 'Nemo??n?? ????slo ??ivota.');
    END IF;
    zivot_unique_check(:new.Macka_id, :new.cislo_zivota);
END;

-- Triggery na validaciu datumov
CREATE OR REPLACE TRIGGER trigger_valid_date_byva
	BEFORE INSERT OR UPDATE ON Byva
	FOR EACH ROW
BEGIN
	IF :new.zabyvanie is null OR :new.zabyvanie > sysdate THEN
		Raise_Application_Error(-20021, 'Nemo??n?? d??tum zab??vania.');
	END IF;
    IF :new.odchod is not null AND :new.zabyvanie > :new.odchod THEN
        Raise_Application_Error(-20022, 'Nemo??n?? d??tum odchodu.');
  END IF;
END;

CREATE OR REPLACE TRIGGER trigger_valid_date_jepozicane
	BEFORE INSERT OR UPDATE ON JePozicane
	FOR EACH ROW
BEGIN
	IF :new.pozicane is null OR :new.pozicane > sysdate THEN
		Raise_Application_Error(-20023, 'Nemo??n?? d??tum po??i??ania.');
	END IF;
    IF :new.vratene is not null AND :new.pozicane > :new.vratene THEN
        Raise_Application_Error(-20024, 'Nemo??n?? d??tum vr??tenia.');
  END IF;
END;

CREATE OR REPLACE TRIGGER trigger_valid_date_jeprivlastnene
	BEFORE INSERT OR UPDATE ON JePrivlastnene
	FOR EACH ROW
BEGIN
	IF :new.privlastnenie is null OR :new.privlastnenie > sysdate THEN
		Raise_Application_Error(-20025, 'Nemo??n?? d??tum privlastnenia.');
	END IF;
    IF :new.odhodenie is not null AND :new.privlastnenie > :new.odhodenie THEN
        Raise_Application_Error(-20026, 'Nemo??n?? d??tum odhodenia.');
  END IF;
END;

-------------- INSERT TEST DATA ---------------
insert into Rasa values ('perzsk??', 'zelen??', 'Perzia', 3, 20);
insert into Rasa values ('beng??lska', '??erven??', 'Beng??lsko', 2, 12);
insert into Rasa values ('britsk??', 'modr??', 'Ve??k?? Brit??nia', 2, 12);
insert into Rasa values ('r??mska', '??ierna', 'R??mska r????a', 1, 0);

insert into Macka(meno, vzor_koze, farba_srsti, hmotnost, rasa) values ('Killer Queen', '??iadny', 'ru??ov??', 70, 'perzsk??');
insert into Macka(meno, vzor_koze, farba_srsti, hmotnost, rasa) values ('Al??beta', 'tigrovan??', '??ierna', 10, 'perzsk??');
insert into Macka(meno, vzor_koze, farba_srsti, hmotnost, rasa) values ('Lea', '??iadny', '??lt??', 7, 'beng??lska');
insert into Macka(meno, vzor_koze, farba_srsti, hmotnost, rasa) values ('Muro', '??iadny', 'ru??ov??', 10, 'britsk??');

insert into Admin(Macka_id) values (1);

insert into Zivot(Macka_id, cislo_zivota, miesto_narodenia, miesto_umrtia, sposob_smrti) values (1, 7, 'Morioh, JP', 'Morioh, JP', 'ORAORA... AMBULANCE');
insert into Zivot(Macka_id, cislo_zivota, miesto_narodenia, miesto_umrtia, sposob_smrti) values (2, 1, 'TT', 'TT', 'vibe check');
insert into Zivot(Macka_id, cislo_zivota, miesto_narodenia, miesto_umrtia, sposob_smrti) values (2, 2, 'Blava', '', '');

insert into Hostitel(meno, datum_narodenia, pohlavie, bydlisko, pref_rasy) values ('Yoshikage Kira', TO_DATE('1966/01/30', 'yyyy/mm/dd'), 'mu??', 'Morioh, JP', rasy('perzsk??', 'britsk??'));

insert into Nazov(Macka_id, Hostitel_id, meno_od_hostitela) values (1, 1, 'Kitty Q');

insert into Teritorium(typ_teritoria, kapacita) values ('z??hrada', 20);
insert into Teritorium(typ_teritoria, kapacita) values ('ob??va??ka', 8);

insert into Vec(typ_veci, kvantita) values ('Sheer Heart Attack', 2);
insert into Vec(typ_veci, kvantita) values ('Bites The Dust', 1);

insert into Spravuje(teritorium_id, hostitel_id) values (1, 1);

insert into Byva(zabyvanie, odchod, Macka_id, Teritorium_id) values (to_date('1975/05/25', 'yyyy/mm/dd'), to_date('1999/07/30', 'yyyy/mm/dd'), 1, 1);
insert into Byva(zabyvanie, odchod, Macka_id, Teritorium_id) values (to_date('2000/02/02', 'yyyy/mm/dd'), to_date('2008/03/16', 'yyyy/mm/dd'), 3, 2);
insert into Byva(zabyvanie, odchod, Macka_id, Teritorium_id) values (to_date('2000/02/02', 'yyyy/mm/dd'), NULL, 2, 1);

insert into JePozicane(pozicane, vratene, Vec_id, Hostitel_id) values (to_date('1999/07/25', 'yyyy/mm/dd'), NULL, 2, 1);

insert into JePrivlastnene (privlastnenie, odhodenie, Vec_id, Macka_id) values (to_date('1999/07/26', 'yyyy/mm/dd'), NULL, 2, 1);

-------------- SELECT ---------------
-- 2x spojenie 2 tabuliek
-- Vypise dlzku zivota, miesto narodenia, miesto umrtia a sposob smrti macky Killer Queen
SELECT Z.cislo_zivota, Z.miesto_narodenia, Z.miesto_umrtia, Z.sposob_smrti
FROM Macka M, Zivot Z
WHERE Z.Macka_id = M.id and M.meno='Killer Queen';
-- Vypise mena mackiek, ktore su perzskej rasy
SELECT M.meno
FROM Macka M, Rasa R
WHERE M.rasa = R.nazov and R.nazov='perzsk??';

-- 1x spojenie 3 tabuliek
-- Vypise meno macky a teritorium, v ktorom sa byva
SELECT M.meno, T.typ_teritoria
FROM Teritorium T, Macka M, Byva B
WHERE T.id = B.Teritorium_id and M.id = B.Macka_id;

-- 2x GROUP BY
-- Vypise mena maciek, ktore maju zaznamenane zivoty a napise k nim cislo posledneho zivota
SELECT M.meno, max(Z.cislo_zivota)
FROM Zivot Z, Macka M
WHERE Z.Macka_id = M.id
GROUP BY Z.Macka_id, M.meno;
-- Vypise nazov rasy a pocet maciek, ktore do danej rasy patria
SELECT M.rasa, count(M.rasa)
FROM Macka M
GROUP BY M.rasa;

-- 1x EXISTS
-- Vypise mena maciek, ktore maju hostitela
SELECT M.meno
FROM Macka M
WHERE EXISTS
(
  SELECT *
  FROM Nazov N
  WHERE M.id = N.Macka_id
);

-- 1x IN s vnorenym selectom
-- Vypise mena maciek, ktore sa zabyvali v obdobi od 01.01.1970 do 01.01.1980
SELECT M.meno
FROM Macka M
WHERE M.id
IN
(
  SELECT B.Macka_id
  FROM Byva B
  WHERE B.zabyvanie BETWEEN '01-01-1970' and '01-01-1980'
);

------- EXPLAIN PLAN a Index --------
SELECT M.meno, max(Z.cislo_zivota)
FROM Zivot Z, Macka M
WHERE Z.Macka_id = M.id
GROUP BY Z.Macka_id, M.meno;

EXPLAIN PLAN FOR
    SELECT M.meno, max(Z.cislo_zivota)
    FROM Zivot Z, Macka M
    WHERE Z.Macka_id = M.id
    GROUP BY Z.Macka_id, M.meno;
SELECT * FROM TABLE(DBMS_XPLAN.display);

CREATE INDEX index_explain ON Zivot (Macka_id, cislo_zivota);

EXPLAIN PLAN FOR
    SELECT M.meno, max(Z.cislo_zivota)
    FROM Zivot Z, Macka M
    WHERE Z.Macka_id = M.id
    GROUP BY Z.Macka_id, M.meno;
SELECT * FROM TABLE(DBMS_XPLAN.display);

---------- Zavolanie procedur ----------
BEGIN
    pocet_mackiek_v_teritoriu ('z??hrada');
    pocet_mackiek_v_teritoriu ('z??hada');
    zivot_unique_check(1, 1); -- neexistuje, je to OK (procedura sa vola triggerom)
END;

---------- MATERIALIZED VIEW -----------
GRANT ALL ON Rasa TO xmlkvy00;
GRANT ALL ON Macka TO xmlkvy00;
GRANT ALL ON Zivot TO xmlkvy00;
GRANT ALL ON Hostitel TO xmlkvy00;
GRANT ALL ON Nazov TO xmlkvy00;
GRANT ALL ON Teritorium TO xmlkvy00;
GRANT ALL ON Vec TO xmlkvy00;

DROP MATERIALIZED VIEW PocetMaciekRovnakejFarbySrsti;

CREATE MATERIALIZED VIEW LOG ON Macka WITH PRIMARY KEY, ROWID(farba_srsti) INCLUDING NEW VALUES;

CREATE MATERIALIZED VIEW PocetMaciekRovnakejFarbySrsti
    CACHE
    BUILD IMMEDIATE
    REFRESH FAST ON COMMIT
    ENABLE QUERY REWRITE
    AS SELECT M.farba_srsti, count(M.farba_srsti) as Pocet
    FROM Macka M
    GROUP BY M.farba_srsti;

GRANT ALL ON PocetMaciekRovnakejFarbySrsti TO xmlkvy00;

SELECT * from PocetMaciekRovnakejFarbySrsti;
INSERT INTO Macka (meno, vzor_koze, farba_srsti, hmotnost, rasa) VALUES ('Julius Caesar', 'dobodkovan??', 'bezchlp??', 76, 'r??mska');
COMMIT;
SELECT * from PocetMaciekRovnakejFarbySrsti;

