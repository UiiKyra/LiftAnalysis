/*Data Preprocessing*/
/*Creating Library*/
libname Model1 "D:\Models\Model1 ";
run;

/*defining macro for variables*/
%let cont = Age Salary TotalGift MinGift MaxGift ;
%let cat = Woman City Education SeniorList NbActivities Referrals Frequency Recency Seniority GaveLastYear;
%let imp = Frequency Recency Seniority TotalGift MinGift MaxGift;

/*imputing hist2*/
data Model1.hist2mark;
set Model1.hist2;
if Recency = . then Ind1 = 0;
else Ind1 = 1;
run;

proc stdize data= Model1.hist2mark out= Model1.hist2imp reponly missing=0;
var &imp;
run;

/*split hist2 into 2 datasets based on contacted or not post imputation*/
data Model1.histCon Model1.histNoc;
set Model1.hist2imp;
if contact = 1 then output Model1.histCon;
else output Model1.histNoc;
run;


/*imputing score contact*/
data Model1.score2mark;
set Model1.score2_contact ;
if Recency = . then Ind1 = 0;
else Ind1 = 1;
run;

proc stdize data= Model1.score2mark out= Model1.Score2Con reponly missing=0;
var &imp;
run;

/*imputing score no contact*/
data Model1.score2markNC;
set Model1.score2_nocontact  ;
if Recency = . then Ind1 = 0;
else Ind1 = 1;
run;

proc stdize data= Model1.score2markNC out= Model1.Score2Noc reponly missing=0;
var &imp;
run;

/*train test split*/
data Model1.trainCon Model1.validCon;
set Model1.histcon;
if ranuni(7)<=0.8 then output Model1.trainCon; else output Model1.validCon;
run;

/*NoCon*/
data Model1.trainNoc Model1.validNoc;
set Model1.histnoc ;
if ranuni(7)<=0.8 then output Model1.trainNoc; else output Model1.validNoc;
run;


/*Model Building*/

/*Linear*/
proc glmselect data=Model1.traincon valdata=Model1.validcon;
class &cat;
model AmtThisYear =&cat &cont /
selection= backward select=sbc;
score data = Model1.score2con  out =  Model1.AmountCon;
run;

proc glmselect data=Model1.trainnoc  valdata=Model1.validnoc ;
class &cat;
model AmtThisYear =&cat &cont /
selection= backward select=sbc;
score data = Model1.score2noc   out =  Model1.AmountNoc;
run;


/*Logistic*/
proc logistic data=Model1.histcon;
	class &cat;
	model GaveThisYear = &cat &cont;
	score data = Model1.Score2con out =  Model1.ProbCon;
run;
quit;

proc logistic data=Model1.histnoc;
	class &cat;
	model GaveThisYear = &cat &cont;
	score data = Model1.Score2noc out =  Model1.ProbNoc;
run;
quit;

/*Uplift Analysis*/

/*Rename amount columns*/
data Model1.LiftAmountCon;
   rename p_AmtThisYear=AmountCon;
   set Model1.amountcon;
run;
data Model1.LiftAmountNoc;
   rename p_AmtThisYear=AmountNoc;
   set Model1.amountnoc;
run;

/*Renaming the Probability Column*/
data Model1.LiftProbCon;
   rename P_1=PCon;
   set Model1.probcon;
run;

data Model1.LiftProbnoc;
   rename P_1=PNoc;
   set Model1.probnoc;
run;


/*Need to calculate Lift*/
/*Merging tables*/

data Model1.Table_lift_1;
merge 
	Model1.LiftAmountCon
	Model1.LiftAmountNoc(keep=AmountNoc)
	Model1.LiftProbCon(keep=PCon)
	Model1.Liftprobnoc(keep=PNoc);
run;

data Model1.Lift_Desc;
      set Model1.Table_lift_1;
	  Econ = AmountCon*PCon;
	  Enoc = AmountNoc*PNoc;
	  Lift = Econ - Enoc;
run;

proc sort data=Model1.lift_desc out=Model1.Lift_sorted;
   by descending Lift ;
run;


proc sql;
create table Model1.Final_IDs as
select ID
from Model1.Lift_sorted
where Lift >= 25;
quit;

%ds2csv (
   data=Model1.Final_IDs, 
   runmode=b, 
   csvfile=D:\Models\Model1\ID.csv
 );



