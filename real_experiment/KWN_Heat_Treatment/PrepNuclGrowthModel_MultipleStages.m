function [FinalStrength,FinalAveRadius,FinalPhaseFraction ]=PrepNuclGrowthModel_MultipleStages(myxmatrix,mycooktemp,myCookTime,...
    myEm,myiSurfen,myfSurfen,myRadsurfenchange)

myCookTime=round(myCookTime);
mycooktemp=round(mycooktemp);
mycookstepcount=length(mycooktemp);
% preallocate variable
%BinSize=ceil(sum(cooktime));

BinSize=sum(myCookTime);
Binprecippercum=zeros(1,BinSize);
Bperbinpercum=zeros(1,BinSize);
dominantmechanism=zeros(1,BinSize);
Binmatpercum=zeros(1,BinSize);
xmatrix=zeros(1,BinSize);
rcritnuc=zeros(1,BinSize);
totaltime=zeros(1,BinSize);
nucrate=zeros(1,BinSize);
numprecippercum=zeros(1,BinSize);
aveBperprecip=zeros(1,BinSize);
averad=zeros(1,BinSize);
steprad=zeros(1,BinSize);
phasefraction=zeros(1,BinSize);
precipedgespacing=zeros(1,BinSize);
ordered=zeros(1,BinSize);
orowan=zeros(1,BinSize);
mismatch=zeros(1,BinSize);
coherency=zeros(1,BinSize);
mismatchandcoherency=zeros(1,BinSize);
strength=zeros(1,BinSize);
Z=zeros(1,BinSize);
Bstar=zeros(1,BinSize);
dGv=zeros(1,BinSize);
cooksteptime=zeros(1,BinSize);
numberofnucleations=zeros(1,BinSize);
Bperprecip=zeros(1,BinSize);
xsolvus=zeros(1,BinSize);
taufract=zeros(1,BinSize);


%Set initial counters
timestep=1;
totalbinnumber=1;
cookstepcount=1;
totaltime(totalbinnumber)=0;


%% definition of heat treatment process parameters

%xmatrix(totalbinnumber)=0.001; %initial matrix composition,
xmatrix=myxmatrix; %initial matrix composition,
%in fraction solute              unitless

%cooktemp=[200,250,300,325,350,375,400,425,450,475,500];
cooktemp=mycooktemp;
%cooktemp=mycooktemp;

%Set temps for each heat treat step                         C
%cooktime=[10800,10800,10800,10800,10800,10800,10800,10800,10800,10800,10800];
cooktime=myCookTime;
%Set times for heat treat steps                             s
cooksteps=mycookstepcount; %number of heat treat steps considered, taken
%from cooktemp and cooktime arrays                          unitless
taufract(1)=1; %initial fraction of incubation time completed.
%0 means fully homogenous, 1 means solute atoms are fully
%clustered and nucleation can start immediately             unitless

%Definition of modeling parameters

minunitcells=2; %minimum number of unit cells for a precip
%to be considered a precip                      unitless
dx=0.000000000000001; %change in composition used in Gibbs
%energy equations to determine solvus composition       unitless


%Definition of universal constants

gas=8.314;
avo=6.0221413e23; %avogadro's number
boltz=gas/avo; %boltzmann's constant



FinalStrength=zeros(1,cookstepcount);
FinalAveRadius=zeros(1,cookstepcount);
FinalPhaseFraction=zeros(1,cookstepcount);
%% Definition of material constants

Dcoeff=0.000531;
Ef=1.05; %vacancy formation energy next to Sc atoms             eV/vacancy

Em=myEm; %migration energy of Sc in Al with Si present,
%would be 0.45 with Si, 0.74 without Si                eV/atom
f=0.7815; %dimensionless correlation factor (0.7815 for FCC)    unitless
GoBb=3347; %see next line                                       J/mol
GoBm=-0.02; %components of calculated gibbs free energy
%for pure B, assuming gibbs free energy of pure A is 0.
%Usage as:    GoB=GoBb+GoBm*tempk                           J/mol/K
dGfpb=-34791;%see next line                                     J/mol
dGfpm=2.789; %components of calculated gibbs free energy
%for the formation of precipitate phase.
%Usage as:    dGfp=dGfpb+dGfpm*tempk                        J/mol/K
Aob=-74918;%see next line                                       J/mol
Aom=-11.021; %components of the coefficient for calculating
%excess Gibbs free energy for the solution phase.
%Usage in FCC as:  xAxB(Ao); Ao=Aob+Aom*tempk               J/mol/K
ap=0.0000000004103; %lattice parameter for the precipitate      m

totalatomsap=4; %number of atoms per unit cell of precipitate   unitless
xp=0.25; %precipitate composition in fraction solute            unitless
am=0.00000000040496; %lattice parameter for matrix phase        m
totalatomsam=4; %number of atoms per unit cell of matrix        unitless
v=0.345; %poisson's ratio for FCC aluminum                      unitless
orientationfactor=3.06;%Taylor mean orientation factor, M       unitless
burgers=0.000000000286;%magnitude of the Burgers vector         m
apbenergy=0.5;%antiphase boundary energy for (111) plane        J/m^2
gm=25400000000; %shear modulus of matrix (pure Al)              Pa
gp=68000000000; %shear modulus of precipitate                   Pa
isurfen=myiSurfen; %initial/nucleation surface energy               J/m^2
fsurfen=myfSurfen; %final/coarsening surface energy                 J/m^2
radsurfenchange=myRadsurfenchange; %radius of precipitate above       m
%which fsurfen becomes the surface energy

%Variables calculated from inputs

misfit=(ap-am)/am; %difference in lattice parameters between
%matrix and precipitate                                 unitless
molvol=(avo*(ap^3))/totalatomsap; %molar volume of atoms in
%the precipitate phase                                  m^3/mol
dm=(gm*(1+v))/(1-2*v); %constants for use in dGs equation
dp=(gp*(1+v))/(1-2*v); %constants for use in dGs equation
dissolutionsize=ap*(minunitcells*3/(4*pi))^(1/3); %radius
%below which precipitates aren't really precipitates    m^3
msurfen=(fsurfen-isurfen)/radsurfenchange; %slope of a linear
%correlation between radius and surface energy at
%precipitate radii below radsurfenchange


%Nucleation sites

nvinitial=xmatrix(totalbinnumber)*totalatomsam/(am^3);
%determines the number of nucleation sites per m^3,
%assuming complete initial supersaturation and that
%each solute atom is a nucleation site                  #/m^3
Binmatpercum(totalbinnumber)=nvinitial;

xarconst=2*molvol/(gas);
Binprecippercumconst=4/3*pi*totalatomsap*xp/((ap)^3);
averadconst=3*ap^3/(4*pi*totalatomsap*xp);
orderedconst=0.44*orientationfactor*apbenergy/burgers;
mismatchconst=orientationfactor*0.0078*(gp-gm)^(3/2);
coherencyconst=orientationfactor*2*gm*((ap-am)/am)^(3/2);
orowanconst=0.4*orientationfactor*gm*burgers;

%Loop for each new heat treatment step

while cookstepcount<=cooksteps
    
    cooksteptime(totalbinnumber)=0;
    
    
    %temperature dependent calculated variables
    
    tempk=cooktemp(cookstepcount)+273; %converts current temp to Kelvin
    %Diff=Dcoeff*exp(-Ea/(gas*tempk)); %calculated diffusion rate
    Diff=Dcoeff*f*exp((-(Ef+Em)*1.60217646*10^(-19))/(boltz*tempk));
    %calculated diffusion rate
    GoB=GoBb+GoBm*tempk; %calculated gibbs free energy of
    %pure B, assuming gibbs free energy of pure A is 0
    GoA=0; %gibbs free energy of pure A, set to 0
    dGfp=dGfpb+dGfpm*tempk; %gibbs free energy of the
    %precipitate phase
    xsolvuscheck=xp/2; %initial guess for the solvus
    %composition, set at half xp
    xsolvusstep=xsolvuscheck/2; %distance (from the initial guess) to check
    
    
    %calculation of solvus composition
    %For each iteration, this loop calculates the slopes of the tie lines
    %between the gibbs free energy of the matrix and precipitate phases for
    %three different matrix compositions. It then chooses the composition
    %that resulted in the smallest slope as the new guess and halves the
    %distance between guesses before creating a new low and high guess for
    %the next iteration. The loop ends when the step size is below 1e-10
    
    while xsolvusstep>0.0000000001;
        gsolvuscheck=GoA*(1-xsolvuscheck)+GoB*xsolvuscheck+gas*tempk*(xsolvuscheck*log(xsolvuscheck))+(1-xsolvuscheck)*log(1-xsolvuscheck)+xsolvuscheck*(1-xsolvuscheck)*(Aob+Aom*tempk);
        %calculates the gibbs free energy of the currently guessed
        %solvus composition along the matrix phase curve
        msolvuscheck=(dGfp-gsolvuscheck)/(xp-xsolvuscheck); %calculates
        %slope of the tie line between gibbs free energies of the
        %precipitate phase and the guessed solvus composition
        
        
        %same as above, but with lower guess (initially half distance
        %from middle guess to A)
        
        xsolvuschecklow=xsolvuscheck-xsolvusstep;
        gsolvuschecklow=GoA*(1-xsolvuschecklow)+GoB*xsolvuschecklow+gas*tempk*(xsolvuschecklow*log(xsolvuschecklow))+(1-xsolvuschecklow)*log(1-xsolvuschecklow)+xsolvuschecklow*(1-xsolvuschecklow)*(Aob+Aom*tempk);
        msolvuschecklow=(dGfp-gsolvuschecklow)/(xp-xsolvuschecklow);
        
        
        %same as above, but with higher guess (initially half distance
        %from middle guess to precipitate composition)
        
        xsolvuscheckhigh=xsolvuscheck+xsolvusstep;
        gsolvuscheckhigh=GoA*(1-xsolvuscheckhigh)+GoB*xsolvuscheckhigh+gas*tempk*(xsolvuscheckhigh*log(xsolvuscheckhigh))+(1-xsolvuscheckhigh)*log(1-xsolvuscheckhigh)+xsolvuscheckhigh*(1-xsolvuscheckhigh)*(Aob+Aom*tempk);
        msolvuscheckhigh=(dGfp-gsolvuscheckhigh)/(xp-xsolvuscheckhigh);
        
        
        %select the composition with the highest slope out of the guess and
        %lower step (slopes are neg so the highest slope is most shallow)
        
        if msolvuschecklow>msolvuscheckhigh
            msolvuscheck=msolvuschecklow;
            xsolvuscheck=xsolvuschecklow;
        end
        
        
        %select the composition with the highest slope between the winner
        %of the last block and the higher step
        
        if msolvuscheckhigh>msolvuscheck
            msolvuscheck=msolvuscheckhigh;
            xsolvuscheck=xsolvuscheckhigh;
        end
        
        
        %halves the checkstep size, to focuse in on the solvus composition
        
        xsolvusstep=xsolvusstep/2;
        
        
    end
    
    %sets the newly found solvus composition
    
    xsolvus(cookstepcount)=xsolvuscheck;
    
    %loop for every timestep within this heat treatment step, nucleating,
    %growing, and dissolving precipitates
    
    while cooksteptime(totalbinnumber)<cooktime(cookstepcount)
        
        %determine the gibbs free energy of compositions slightly above
        %and below the matrix composition, and use these values to find the
        %slope and intercept of a tangential line to the energy curve. This
        %tangential line is used to determine the change in gibbs energy
        %due to the formation of precipitate volume
        
        xmathigh=xmatrix(totalbinnumber)+dx;
        xmatlow=xmatrix(totalbinnumber)-dx;
        gmatrix=GoA*(1-xmatrix(totalbinnumber))+GoB*xmatrix(totalbinnumber)+gas*tempk*(xmatrix(totalbinnumber)*log(xmatrix(totalbinnumber))+(1-xmatrix(totalbinnumber))*log(1-xmatrix(totalbinnumber)))+xmatrix(totalbinnumber)*(1-xmatrix(totalbinnumber))*(Aob+Aom*tempk);
        gmathigh=GoA*(1-xmathigh)+GoB*xmathigh+gas*tempk*(xmathigh*log(xmathigh)+(1-xmathigh)*log(1-xmathigh))+xmathigh*(1-xmathigh)*(Aob+Aom*tempk);
        gmatlow=GoA*(1-xmatlow)+GoB*xmatlow+gas*tempk*(xmatlow*log(xmatlow)+(1-xmatlow)*log(1-xmatlow))+xmatlow*(1-xmatlow)*(Aob+Aom*tempk);
        mmatrix=(gmathigh-gmatlow)/(xmathigh-xmatlow);
        bmatrix=gmatrix-mmatrix*xmatrix(totalbinnumber);
        Gpm=mmatrix*xp+bmatrix;
        dGv(totalbinnumber)=(dGfp-Gpm)/molvol;
        dGs=3*misfit^2*dp*(1-1/(1+(3*dm*(1-v))/(dp*(1+v))-dm/dp));
        
        
        %calculate the critical radius of nucleation, based on surface
        %energy, which can vary at very low radii due to preferential
        %formation of the most preferential interfaces. Here it is assumed
        %to vary linearly up to a radius of radsurfenchange
        
        rcritnuc(totalbinnumber)=-2*isurfen/(dGv(totalbinnumber)+dGs+2*msurfen);
        
        if rcritnuc(totalbinnumber)>=radsurfenchange||rcritnuc(totalbinnumber)<0
            rcritnuc(totalbinnumber)=-2*fsurfen/(dGv(totalbinnumber)+dGs);
        end
        
        
        %if dGv + dGs is neg, the crit radius will be calculated as neg,
        %which should not be rewritten as dissolution size, as
        %precipitation is extremely unlikely in this scenario.
        
        if rcritnuc(totalbinnumber)<0
            rcritnuc(totalbinnumber)=rcritnuc(totalbinnumber-1);
        end
        
        %Reset critical radius to the minimum possible precipitate size if
        %it is impossibly small, so only realistic precipitates form
        
        if rcritnuc(totalbinnumber)<dissolutionsize
            rcritnuc(totalbinnumber)=dissolutionsize;
        end
        
        
        %Calculate surface energy for precipitates with critical radius.
        %Done now in case dissolution size was above radsurfenchange and
        %rcritnuc was just reset
        
        if rcritnuc(totalbinnumber)>=radsurfenchange
            surfen=fsurfen;
        else
            surfen=(msurfen*rcritnuc(totalbinnumber)+isurfen);
        end
        
        %Calculate nucleation of precips for the current timestep
        
        atomvolm=(1-xmatrix(totalbinnumber)/xp)/totalatomsam*(am^3)+xmatrix(totalbinnumber)/xp*(ap^3)/totalatomsap;
        %calculating the average volume per atom in the matrix,
        %assuming identical crystal structures and that the lattice
        %stretches around each B atom as if it was in precipitate phase
        Z(totalbinnumber)=atomvolm*(dGv(totalbinnumber)+dGs)^2/(8*pi*sqrt(surfen^3*boltz*tempk));
        %calculating the Zeldovich nonequilibrium factor
        Bstar(totalbinnumber)=(16*pi*surfen^2*xmatrix(totalbinnumber)*Diff)/((dGv(totalbinnumber)+dGs)^2*(ap)^4);
        %calculating beta star, rate of atomic attachment to an embryo
        tau=(8*boltz*tempk*surfen*(ap)^4)/(atomvolm^2*(dGv(totalbinnumber)+dGs)^2*Diff*xmatrix(totalbinnumber));
        %calculating the incubation time required for nucleation
        nucrate(totalbinnumber)=(Binmatpercum(totalbinnumber)-(4*xsolvus(cookstepcount))/(am^3))*Z(totalbinnumber)*Bstar(totalbinnumber)*exp((-4*pi*surfen*rcritnuc(totalbinnumber)^2)/(3*boltz*tempk))*exp(-tau/(tau*taufract(cookstepcount)+cooksteptime(totalbinnumber)));
        %calculating the homogeneous nucleation rate        #/m^3/s
        numberofnucleations(totalbinnumber)=timestep*nucrate(totalbinnumber);
        %calculating the number of nucleations this
        %timestep, more useful if timestep is variable      #/m^3
        
        %If precipitates were formed during this time step: store radius
        %(critical radius), calculate # of B atoms used for each
        %precipitate and for the sum of all newly formed precips
        
        if numberofnucleations(totalbinnumber)>=1&&rcritnuc(totalbinnumber)>=dissolutionsize
            
            steprad(totalbinnumber)=rcritnuc(totalbinnumber);
            %the radius of the precipitates formed at this step
            Binprecippercum(totalbinnumber)=Binprecippercumconst*numberofnucleations(totalbinnumber)*steprad(totalbinnumber)^3;
            %the amount of B atoms in all precips per m^3
            numprecippercum(totalbinnumber) = numberofnucleations(totalbinnumber);
            %number of precips per m^3, incomplete at this point
            %because preexisting precips haven't been added yet
        else
            steprad(totalbinnumber)=0;
        end
        
        %loop to calculate coarsening behavior of all previously formed
        %precipitates, starting with first historical timestep with
        %nucleation
        
%         Iteratingbinnumber=1;
%         
%         while Iteratingbinnumber<totalbinnumber
%             
%             if steprad(Iteratingbinnumber)>=dissolutionsize
%                 
%                 
%                 %if radius of precipitates nucleated at time
%                 %Iteratingbinnumber is physically possible, the precipitate
%                 %will grow/shrink depending on Gibbs-Thomson relations
%                 
%                 if steprad(Iteratingbinnumber)>=radsurfenchange
%                     surfen=fsurfen;
%                 else
%                     surfen=(msurfen*steprad(Iteratingbinnumber)+isurfen);
%                 end
%                 
%                 xar=xsolvus(cookstepcount)*exp(xarconst*surfen/(tempk*steprad(Iteratingbinnumber)));
%                 %the effective equilibrium composition at edge of
%                 %precipitates in this bin, accounting for gibbs-thomson
%                 steprad(Iteratingbinnumber)=steprad(Iteratingbinnumber)+timestep*(Diff*(xmatrix(totalbinnumber)-xar))/((xp-xar)*steprad(Iteratingbinnumber));
%                 %calculated radius of precipitates in this bin after
%                 %the current timestep
%                 numprecippercum(totalbinnumber) = numprecippercum(totalbinnumber)+numberofnucleations(Iteratingbinnumber);
%                 
%             else
%                 
%                 %dissolve precipitates if they are below the minimal
%                 %physical precipitate size.
%                 
%                 steprad(Iteratingbinnumber)=0;
%             end
%             
%             Binprecippercum(totalbinnumber)=Binprecippercum(totalbinnumber)+Binprecippercumconst*numberofnucleations(Iteratingbinnumber)*steprad(Iteratingbinnumber)^3;
%             
%             %look at the next historical timestep and loop
%             
%             Iteratingbinnumber=Iteratingbinnumber+1;
%             
%         end
        
        [Binprecippercum_totalbin,steprad,numprecipercum_totalbinnum]=IterationBinFunction_Matlab...
            (totalbinnumber,dissolutionsize,steprad,radsurfenchange,fsurfen,isurfen,msurfen,xsolvus(cookstepcount),...
            timestep,Binprecippercum(totalbinnumber),...
            xarconst,tempk,Diff,xmatrix(totalbinnumber),numberofnucleations,xp,Binprecippercumconst); % 18 inputs and 3 outputs
        
        numprecippercum(totalbinnumber)=numprecippercum(totalbinnumber)+numprecipercum_totalbinnum;
        Binprecippercum(totalbinnumber)=Binprecippercum_totalbin;
        
        %Calculate number of B atoms still in the matrix after all
        %nucleation/coarsening and calculate the new matrix composition
        
        if numprecippercum(totalbinnumber)>0
            
            aveBperprecip(totalbinnumber) = Binprecippercum(totalbinnumber) / numprecippercum(totalbinnumber);
        else
            aveBperprecip(totalbinnumber)=0;
        end
        
        averad(totalbinnumber)=(averadconst*aveBperprecip(totalbinnumber))^(1/3);
        
        Binmatpercum(totalbinnumber)=nvinitial-(Binprecippercum(totalbinnumber));
        xmatrix(totalbinnumber+1)=Binmatpercum(totalbinnumber)*(am^3)/totalatomsam;
        Binmatpercum(totalbinnumber+1)=Binmatpercum(totalbinnumber);
        
        %strengthening calculations
        
        phasefraction(totalbinnumber)=(xmatrix(1)-xmatrix(totalbinnumber+1))/xp;
        precipedgespacing(totalbinnumber)=averad(totalbinnumber)*(sqrt(2*pi/(3*phasefraction(totalbinnumber)))-pi/2);
        ordered(totalbinnumber)=orderedconst*sqrt(phasefraction(totalbinnumber));
        mismatch(totalbinnumber)=mismatchconst*sqrt(phasefraction(totalbinnumber)/gm)*(averad(totalbinnumber)/burgers)^0.275;
        coherency(totalbinnumber)=coherencyconst*sqrt(averad(totalbinnumber)*phasefraction(totalbinnumber)/burgers);
        mismatchandcoherency(totalbinnumber)=mismatch(totalbinnumber)+coherency(totalbinnumber);
        
        if averad(totalbinnumber)>0
            orowan(totalbinnumber)=(orowanconst*log(2*averad(totalbinnumber)/burgers))/(pi*precipedgespacing(totalbinnumber)*sqrt(1-v));
        else
            
            %if no precipitates have formed, averad is 0, and the orowan
            %equation returns NaN because of log(0). Therefore we bypass it
            %and set orowan strength to 0 so the code can handle it
            orowan(totalbinnumber)=0;
        end
        
        
        %Determine which strengthening mechanism is dominant (represented
        %by 1, 2, and 3) and record predicted effective strengthening
        
        if mismatchandcoherency(totalbinnumber)<orowan(totalbinnumber)&&mismatchandcoherency(totalbinnumber)<ordered(totalbinnumber)
            strength(totalbinnumber)=mismatchandcoherency(totalbinnumber);
            dominantmechanism(totalbinnumber)=1;
        elseif ordered(totalbinnumber)<orowan(totalbinnumber)
            strength(totalbinnumber)=ordered(totalbinnumber);
            dominantmechanism(totalbinnumber)=2;
        else
            strength(totalbinnumber)=orowan(totalbinnumber);
            dominantmechanism(totalbinnumber)=3;
        end
        
        totalbinnumber=totalbinnumber+1;
        
        totaltime(totalbinnumber)=totaltime(totalbinnumber-1)+timestep;
        cooksteptime(totalbinnumber)=cooksteptime(totalbinnumber-1)+timestep;
        
        %Loop unless the time for this heat treatment step has expired
        
    end
    
    FinalStrength(cookstepcount)=strength(totalbinnumber-1)/10^6;
    FinalAveRadius(cookstepcount)=averad(totalbinnumber-1)/10^-9;
    FinalPhaseFraction(cookstepcount)=phasefraction(totalbinnumber-1)/10^-3;
    

        
    %Move to the next heat treatment step and loop unless all of the heat
    %treatment steps have been run
    cookstepcount=cookstepcount+1; %moves to the next heat treatment step
    %FinalStrength(cookstepcount)=FinalStrength(cookstepcount)/3-60;
end


end