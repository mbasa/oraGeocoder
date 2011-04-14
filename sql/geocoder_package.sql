--
-- oraGeocoder.ja : Japanese Geocoder for Oracle
-- Copyright (C) 2011  Mario Basa
--
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 2
-- of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
--
-- このプログラムはフリーソフトウェアです。あなたはこれを、フリーソフトウェ
-- ア財団によって発行された GNU 一般公衆利用許諾契約書(バージョン2か、希
-- 望によってはそれ以降のバージョンのうちどれか)の定める条件の下で再頒布
-- または改変することができます。
-- 
-- このプログラムは有用であることを願って頒布されますが、*全くの無保証* 
-- です。商業可能性の保証や特定の目的への適合性は、言外に示されたものも含
-- め全く存在しません。詳しくはGNU 一般公衆利用許諾契約書をご覧ください。
--  
-- あなたはこのプログラムと共に、GNU 一般公衆利用許諾契約書の複製物を一部
-- 受け取ったはずです。もし受け取っていなければ、フリーソフトウェア財団ま
-- で請求してください(宛先は the Free Software Foundation, Inc., 59
-- Temple Place, Suite 330, Boston, MA 02111-1307 USA)。


CREATE OR REPLACE TYPE geores IS OBJECT (
   		code         integer,
   		x            number,
   		y            number,
    	address      varchar2(80),
   		todofuken    varchar2(40),
   		shikuchoson  varchar2(40),
   		ooaza        varchar2(40),
   		chiban       varchar2(40),  
   		go           varchar2(40)
); 
/

CREATE OR REPLACE PACKAGE geocoder_jp IS

    TYPE t_array IS TABLE OF VARCHAR2(50)
       INDEX BY BINARY_INTEGER;
	
	FUNCTION geocode(address IN VARCHAR2) RETURN geores;
	FUNCTION normalizeAddr(paddress IN VARCHAR2) RETURN varchar2;
	
	FUNCTION searchTodofuken(paddress IN VARCHAR2) RETURN geores;
	FUNCTION searchShikuchoson(paddress IN VARCHAR2,r_todofuken IN VARCHAR2)  
	   RETURN geores;
    FUNCTION searchOoaza(paddress VARCHAR2,r_shikuchoson VARCHAR2) 
       RETURN geores;
    FUNCTION searchChiban( paddress VARCHAR2,r_todofuken VARCHAR2, 
        r_shikuchoson VARCHAR2,r_ooaza VARCHAR2 ) RETURN geores;
   
    FUNCTION SPLIT (p_in_string VARCHAR2, p_delim VARCHAR2) RETURN t_array;
	   
END geocoder_jp;
/

CREATE OR REPLACE PACKAGE BODY geocoder_jp IS
   
FUNCTION  geocode (address IN VARCHAR2) RETURN geores
 AS
   output geores; 
   gc     geores;
   matching_nomatch     integer;
   matching_eki         integer;
   matching_todofuken   integer;
   matching_shikuchoson integer;
   matching_ooaza       integer;
   matching_chiban      integer;
   matching_pinpnt      integer;
 BEGIN
 
  matching_nomatch     := -99;
  matching_eki         := 30;
  matching_todofuken   := 5;
  matching_shikuchoson := 4;
  matching_ooaza       := 3;
  matching_chiban      := 2;
  matching_pinpnt      := 1;

 --   select 9999 into output.code from dual;
 --   output.code := 9999;
   output :=  geores(matching_nomatch,0.0,0.0,'a','a','a','a','a','a');
   
   output := searchTodofuken( address );

   IF output.address <> 'なし' THEN
     output.code := matching_todofuken;
     gc := searchShikuchoson( address,output.todofuken);
   ELSE
     output.code := matching_nomatch;
     gc := searchShikuchoson( address,'');
   END IF;
  
   IF gc.address <> 'なし' THEN
     output := gc;
     output.code := matching_shikuchoson;
     gc := searchOoaza( address,output.shikuchoson );
   ELSE
     RETURN output;
   END IF;
   
   IF gc.address <> 'なし' THEN
    output := gc;
    output.code := matching_ooaza;
    gc := searchChiban( address,output.todofuken,output.shikuchoson,
                                  output.ooaza );
  ELSE
    RETURN output;
  END IF;

  IF gc.address <> 'なし' THEN
    output := gc;
    output.code := matching_chiban;
  END IF;
     
  RETURN output;
  
 END geocode;

--
--  Function to normalize Address for easier matches
--
FUNCTION normalizeAddr(paddress IN VARCHAR2) 
       RETURN varchar2 
 AS
    address  varchar2(180);
    tmpstr   varchar2(180);
    tmparr   t_array;
    st       integer;
    en       integer;
    arrc     integer;
    arrl     integer;
 BEGIN
  
  address := translate(paddress,
      'ヶケ−－ーの１２３４５６７８９０一二三四五六七八九十丁目',
      'kk----1234567890123456789X-');

  IF instr( address, 'X') <> 0 THEN
     tmparr := split(address,'X');
     address:= '';
     arrl   := tmparr.count;
     arrc   := 1;
     
     WHILE (arrc < arrl) LOOP
       st := ascii(substr(tmparr(arrc),length(tmparr(arrc)),1));
       en := ascii(substr(tmparr(arrc+1),1,1));
       
       --
       -- For cases like '十九'
       --
       IF (st < 48 OR st > 57) AND (en >= 48 AND en <= 57) THEN
           IF arrc = 1 THEN
             address :=  address || tmparr(arrc) || '1' ||  tmparr(arrc+1);
           ELSE
             address :=  address ||  '1' ||  tmparr(arrc+1);
           END IF;
       END IF;
       
       --
       -- For cases like '二十九'
       --
       IF (st >= 48 AND  st <= 57) AND (en >= 48 AND en <= 57) THEN
           IF arrc = 1 THEN              
             address :=  address || tmparr(arrc) ||  tmparr(arrc+1);
           ELSE
             address :=  address || tmparr(arrc+1);
           END IF;
       END IF;
            
       --
       -- For cases like '二十'
       --
       IF (st >= 48 AND  st <= 57) AND (en < 48 OR en > 57) THEN
           IF arrc = 1 THEN
               address :=  address || tmparr(arrc) ||  '0' || tmparr(arrc+1);
           ELSE
               address :=  address ||  '0' || tmparr(arrc+1);
           END IF;
       END IF;
        
       --
       -- For cases like '十'
       --
       IF (st < 48 OR  st > 57) AND (en < 48 OR en > 57) THEN
          IF arrc = 1 THEN
             address :=  address || tmparr(arrc) ||  '10' || tmparr(arrc+1);
          ELSE
             address :=  address ||  '10' || tmparr(arrc+1);
          END IF;
       END IF;

       arrc := arrc + 1;
       
     END LOOP;

  END IF;
  
  RETURN address;
  
END normalizeAddr;

--
--  Function to search Todofuken level of an address
--  parameters: address
--
FUNCTION searchTodofuken( paddress IN VARCHAR2 )  RETURN geores 
AS
    address  VARCHAR2(180);
    --rec      address_t%ROWTYPE;
    output   geores;
BEGIN

  output :=  geores(1,2.0,3.0,' ',' ',' ',' ',' ',' ');
  
  output.x         := -999;
  output.y         := -999;
  output.code      := 5;
  output.address   := 'なし';
  output.todofuken := '';

  address := replace(paddress,' ','');
  address := replace(address,'　','');
  
  FOR rec IN 
    ( SELECT *  FROM address_t WHERE address
        LIKE todofuken||'%' )
  LOOP
     output.x         := rec.lon;
     output.y         := rec.lat;
     output.code      := 4;
     output.address   := rec.todofuken;
     output.todofuken := rec.todofuken;
     EXIT;
  END LOOP;
     
  RETURN output;
  
END searchTodofuken;

--
--  Function to search Shikuchoson level of an address
--  parameters: address,todofuken (may be blank)
--
FUNCTION searchShikuchoson( 
    paddress IN VARCHAR2, r_todofuken IN VARCHAR2  )  RETURN geores 
AS 
    address     VARCHAR2(180);
    output      geores;
BEGIN

  output        :=  geores(1,2.0,3.0,' ',' ',' ',' ',' ',' ');
  output.x      := -999;
  output.y      := -999;
  output.address:= 'なし';

  address := replace(paddress,' ','');
  address := replace(address,'　','');

--  DBMS_OUTPUT.PUT_LINE('address: '||ADDRESS ); 

  IF LENGTH( r_todofuken  ) > 2 THEN
     FOR rec IN
        ( SELECT * FROM address_s WHERE 
           todofuken = r_todofuken AND
           address LIKE '%'||shikuchoson||'%'   )
      LOOP
          output.x           := rec.lon;
          output.y           := rec.lat;
          output.code        := 3;
          output.address     := rec.todofuken || rec.shikuchoson;
          output.todofuken   := rec.todofuken;
          output.shikuchoson := rec.shikuchoson;
          EXIT;
       END LOOP; 
    ELSE   
     FOR rec IN
        ( SELECT * FROM address_s WHERE 
            address LIKE shikuchoson||'%'   )
      LOOP
          output.x           := rec.lon;
          output.y           := rec.lat;
          output.code        := 3;
          output.address     := rec.todofuken || rec.shikuchoson;
          output.todofuken   := rec.todofuken;
          output.shikuchoson := rec.shikuchoson;
          EXIT;
       END LOOP; 
   END IF;
   
   RETURN output;

END searchShikuchoson;

--
--  Function to search Ooaza level of an address
--  parameters: address, shikuchoson
--

FUNCTION searchOoaza(paddress VARCHAR2,
                     r_shikuchoson VARCHAR2) RETURN geores 
 AS
  address       varchar2(180);
  tmpstr        varchar2(180);
  tmpaddr       varchar2(180);
  pos           integer;
  output        geores;
 BEGIN

  output         :=  geores(1,2.0,3.0,' ',' ',' ',' ',' ',' ');
  output.x       := -999;
  output.y       := -999;
  output.address := 'なし';

  address := replace(paddress,' ','');
  address := replace(address,'　','');

  pos     := instr(address,r_shikuchoson) + length(r_shikuchoson);
  tmpstr  := substr(address,pos) || '-'; -- to match addresses like 杉並区清水１
  tmpaddr := normalizeAddr( tmpstr );

  -- DBMS_OUTPUT.PUT_LINE('tmp address: '||tmpaddr ); 
  --
  -- the 'Order By length' slows down the operation a bit
  -- but produces more accurate matches.
  --
  
  FOR rec IN
   (SELECT todofuken,shikuchoson,ooaza,lon,lat,length(tr_ooaza) 
    AS length FROM address_o WHERE 
    shikuchoson = r_shikuchoson AND
    instr(tmpaddr,tr_ooaza) = 1 
    ORDER BY length DESC) 
   LOOP
     output.x          := rec.lon;
     output.y          := rec.lat;
     output.code       := 2;
     output.address    := rec.todofuken||rec.shikuchoson||rec.ooaza;
     output.todofuken  := rec.todofuken;
     output.shikuchoson:= rec.shikuchoson;
     output.ooaza      := rec.ooaza;
     EXIT;
  END LOOP;

  RETURN output;

END searchOoaza;

--
--  Function to search Chiban level of an address
--  parameters: address, todofuken, shikuchoson, ooza
--

FUNCTION searchChiban( paddress VARCHAR2,r_todofuken VARCHAR2, 
        r_shikuchoson VARCHAR2,r_ooaza VARCHAR2 ) RETURN geores 
AS 
  address       varchar2(180);
  ooaza         varchar2(260);
  preftab       varchar2(260);
  tmpstr1       varchar2(260);
  tmpstr2       varchar2(260);
  tmpstr3       varchar2(260);
  tmpcnt        integer;
  tmpflag       integer;
  pos           integer;
  output        geores;
BEGIN

  output         :=  geores(1,2.0,3.0,' ',' ',' ',' ',' ',' ');
  output.x       := -999;
  output.y       := -999;
  output.address := 'なし';

--  preftab := ' ';

--  IF length(r_todofuken) > 2 THEN
--    FOR rec IN
--      (SELECT * FROM address_t where todofuken = r_todofuken)
--    LOOP
--      preftab := rec.ttable;
--    END LOOP;
--  END IF;

--  IF length(preftab) < 2 THEN
--    RETURN  output;
--  END IF;

  address := replace(paddress,' ','');
  address := replace(address,'　','');
  address := normalizeAddr( address );

  ooaza := replace(r_ooaza,' ','');
  ooaza := replace(ooaza,'　','');
  ooaza := normalizeAddr( ooaza );

  pos     := instr(address,ooaza)+length(ooaza);
  tmpstr1 := substr(address,pos);
  tmpstr1 := replace(tmpstr1,'X','10');

  tmpcnt  := 1;
  tmpflag := length(tmpstr1);
  tmpstr2 := ' ';
  tmpstr3 := ' ';
  
  WHILE tmpcnt <= tmpflag 
  LOOP
    tmpstr2 := substr(tmpstr1,tmpcnt,1);
   
    IF ascii( tmpstr2 ) >= 48 AND ascii( tmpstr2 ) <= 57 THEN
      tmpstr3 := tmpstr3 || tmpstr2;
    ELSE
      EXIT;
    END IF;
   
    tmpcnt := tmpcnt + 1;
  END LOOP;

 -- DBMS_OUTPUT.PUT_LINE('ooaza:'|| r_ooaza ||',tmpstr3: "'||tmpstr3||'"' ); 

  FOR rec IN
    (SELECT * FROM address WHERE 
     todofuken   = r_todofuken AND
     shikuchoson = r_shikuchoson AND 
     ooaza       = r_ooaza  AND
     chiban      = trim(tmpstr3))
  LOOP   
    output.code       := 1;
    output.x          := rec.lon;
    output.y          := rec.lat;
    output.address    := rec.todofuken||rec.shikuchoson||
                         rec.ooaza||rec.chiban||'番';
    output.todofuken  := rec.todofuken;
    output.shikuchoson:= rec.shikuchoson;
    output.ooaza      := rec.ooaza;
    output.chiban     := rec.chiban;
    EXIT;
  END LOOP;

  
  RETURN output;

END searchChiban;

--
-- Split string by a delimiter
--

FUNCTION SPLIT (p_in_string VARCHAR2, p_delim VARCHAR2) RETURN t_array 
AS  
      i       number :=0;
      pos     number :=0;
      lv_str  varchar2(50) := p_in_string; 
      strings t_array;
BEGIN
   
      -- determine first chuck of string  
      pos := instr(lv_str,p_delim,1,1);
   
      -- while there are chunks left, loop 
      WHILE ( pos != 0) LOOP
         
         -- increment counter 
         i := i + 1;
         
         -- create array element for chuck of string 
         strings(i) := substr(lv_str,1,pos-1);
         
         -- remove chunk from string 
         lv_str := substr(lv_str,pos+1,length(lv_str));
         
         -- determine next chunk 
         pos := instr(lv_str,p_delim,1,1);
         
         -- no last chunk, add to array 
         IF pos = 0 THEN        
            strings(i+1) := lv_str;
         END IF;
      
      END LOOP;
   
      -- return array 
      RETURN strings;
      
END  SPLIT;
   
   
END geocoder_jp;
/

