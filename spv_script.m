%% loading new parameter from csv
nio=pc('input_files/SPV_nio_MAPI(HC)_bilayer.csv');
%% mobility setup
% mucat=1e-13;
% muani=1e-13;
% mue=2e1;
% muh=2e1;
% nio.mucat(end)=mucat;
% nio.muani(end)=muani;
% nio.mue(end)=mue;
% nio.muh(end)=muh;
% 
%% recombination rate setup
% sn_r=1e-10;
% sp_r=1e-10;
% sn_l=1e4;
% sp_l=1e7;
% nio.sn_r=sn_r;
% nio.sp_r=sp_r;
% nio.sp_l=sp_l;
% nio.sn_l=sn_l;

%%
par.test=nio;
soleq.test=equilibrate(par.test);
spvsoltest=dospv(soleq.test.ion,0.2,1,200,100,0e0,0);
spvdattest=spvana(spvsoltest);

%%
figure
plot(spvdattest.t, spvdattest.deltaVt, spvdattest.t, spvdattest.deltaViont, spvdattest.t, spvdattest.SPV)
xlabel('Time [s]')
ylabel('\Delta Electric potential at x=d [V]')
legend('Vtotal', 'Vion', 'Vtotal - Vion')
title(join(['mucat=' num2str(nio.mucat(end)) ' muani=' num2str(nio.muani(end)) ' sn_r=' num2str(nio.sn_r) ' sp_r=' num2str(nio.sp_r)]))