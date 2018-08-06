function [Voc, Vapp_arr, Jtot] = pinAna(solstruct)

% Plotting defaults
set(0,'DefaultLineLinewidth',1);
set(0,'DefaultAxesFontSize',16);
set(0,'DefaultFigurePosition', [600, 400, 450, 300]);
set(0,'DefaultAxesXcolor', [0, 0, 0]);
set(0,'DefaultAxesYcolor', [0, 0, 0]);
set(0,'DefaultAxesZcolor', [0, 0, 0]);
set(0,'DefaultTextColor', [0, 0, 0]);

% Simple structure names
sol = solstruct.sol;
P = solstruct.p;
x = solstruct.x;
t = solstruct.t;

P.x = x;
P.t = t;        % For backwards compatibility

xpoints = length(x);

%% ANALYSIS %%
xnm = x*1e7;    % x in nm for plotting

%%%%% ANALYSIS %%%%%

% split the solution into its component parts (e.g. electrons, holes and efield)
n = sol(:,:,1);
p = sol(:,:,2);
a = sol(:,:,3);
V = sol(:,:,4);

% plot the output
% if OC == 0

%% Binary matrices defining regions of the device

    % p-type binary matrix
    pBM = ones(length(t), P.xpoints)*diag(x <= P.tp);
    % p-i interface binary matrix
    piBM = ones(length(t), P.xpoints)*diag(x > (P.tp) & x <= (P.tp + P.tint));       
    % Intrinsic binary matrix
    iBM = ones(length(t), P.xpoints)*diag(x > P.tp & x < P.tp + P.ti);
    % i-n interface binary matrix II
    inBM = ones(length(t), P.xpoints)*diag(x >= P.tp + P.ti - P.tint & x < P.tp + P.ti);
    % n-type binary matrix
    nBM = ones(length(t), P.xpoints)*diag(x >= P.tp +P.ti  & x <= P.xmax);

n1 = n*P.Bn(1); 
p1 = p*P.Bp(1);

n2 = n*P.Bn(2);
p2 = p*P.Bp(2);

n3 = n*P.Bn(3);
p3 = p*P.Bp(3);

n = pBM.*n1 + iBM.*n2 + nBM.*n3;
p = pBM.*p1 + iBM.*p2 + nBM.*p3;

%nstat = zeros(1, xpoints);                                  % Static charge array
nstat = (-P.NA(1)+P.ND(1))*pBM  + (-P.NA(2) + P.ND(2))*nBM + (-P.NA(3) + P.ND(3))*nBM;
rhoc = (-n + p + nstat);     % Net charge density calculated from adding individual charge densities

% Remove ionic charge densities from contact regions
astat = ((-P.NI)*pBM + (-P.NI)*nBM);
a = a + astat;

EA = P.EA(1)*pBM + P.EA(2)*iBM + P.EA(3)*nBM;
IP = P.IP(1)*pBM + P.IP(2)*iBM + P.IP(3)*nBM;
Ei = P.Eif(1)*pBM  + P.Eif(2)*iBM + P.Eif(3)*nBM;
ni = P.ni(1)*pBM  + P.ni(2)*iBM + P.ni(3)*nBM;
N0 = P.N0(1)*pBM  + P.N0(2)*iBM + P.N0(3)*nBM;

Ecb = EA-V;                                 % Conduction band potential
Evb = IP-V;                                 % Valence band potential
Efn = real(Ecb+(P.kB*P.T/P.q)*log(n./N0));        % Electron quasi-Fermi level 
Efp = real(Evb-(P.kB*P.T/P.q)*log(p./N0));        % Hole quasi-Fermi level
Phin = real(Ei+(P.kB*P.T/P.q)*log(n./ni)-EA);     % Chemical Potential electrons
Phip = real(Ei-(P.kB*P.T/P.q)*log(p./ni)-EA);     % Chemical Potential holes
Phi = Phin - Phip;


if P.OC == 1
    
    Voc = Efn(:, round(P.xpoints/2)) - Efp(:, 1);                    % Open Circuit Voltage
    Voc_chem = Phin(:, round(P.xpoints/2)) - Phip(:, 1);              % Chemical componenet
    Voc_V = V(:, round(P.xpoints/2)) - V(:, 1);

else
    
    Voc = nan;
    
end

if P.OC == 1  && P.pulseon == 1                               % AC coupled mode
   
    Voc = Voc - Voc(1, :);
    t = (t-(P.pulsestart+P.pulselen));          % Zero point adjustment                               
end

if P.OC == 0 && P.pulseon == 1 

    t = (t-P.pulsestart);          % Zero point adjustment   

end


for i=1:length(t)

    Fp(i,:) = -gradient(V(i, :), x);                      % Electric field calculated from V

end

Potp = V(end, :);

rhoctot = trapz(x, rhoc, 2)/P.xmax;   % Net charge

Irho = a - P.NI;                  % Net ionic charge
Irhotot = trapz(x, Irho, 2)/P.xmax;   % Total Net ion charge

ntot = trapz(x, n, 2);     % Total 
ptot = trapz(x, p, 2);

if P.JV == 1
    
    Vapp_arr = P.Vstart + ((P.Vend-P.Vstart)*t*(1/P.tmax));
    
else
    
    Vapp_arr = nan;
    
end

%% Current calculation from continuity equations
  
for j = 1:size(n, 2)
    
    dndt(:,j) = gradient(n(:,j), t);
    dpdt(:,j) = gradient(p(:,j), t);
    
end

dndtInt = trapz(x, dndt, 2);
dpdtInt = trapz(x, dpdt, 2);

% Recombination
Ubtb = P.kradp*(n.*p - P.ni(1)^2).*pBM + P.kradi*(n.*p - P.ni(2)^2).*iBM + P.kradn*(n.*p - P.ni(3)^2).*nBM;

Usrh = ((n.*p*P.Bp(1) - P.ni(2)^2)./((P.taun(1).*(p*P.Bp(1)+P.pt(2))) + (P.taup(1).*(n+P.nt(2))))).*piBM...
            + ((n*P.Bn(3).*p- P.ni(2)^2)./((P.taun(3).*(p+P.pt(2))) + (P.taup(3).*(n*P.Bn(3)+P.nt(2))))).*inBM;
        
U = Ubtb + Usrh;

% Generation

% Uniform Generation
switch P.OM
    
    case 0
      
      if P.Int ~= 0
           
          g = P.Int*P.G0*iBM;
                
      else
          
          g = 0;
      
      end
 
    case 1
        
        % Beer-Lambert - not currently implemented
        g = P.Int*P.alpha*P.I0*exp(-P.alpha*(x-P.tp));
        
    case 2 
        % Transfer Matrix
        if P.Int == 0
            
            g = 0;
            
        else
            
            g = P.Int*interp1(P.genspace, solstruct.Gx1S, (x-P.tp));
            
        end       
      
end
   
    djndx = -(dndt - g + U);    % Not certain about the sign here
    djpdx = -(dpdt - g + U);
    
    % Integrate across the device to get delta fluxes at all positions
    deltajn = cumtrapz(P.x, djndx, 2);
    deltajp = cumtrapz(P.x, djpdx, 2);
    
    %% Currents from the boundaries
    if P.OC
        
        jn_l = 0;
        jp_l = 0;
        jn_r = 0;
        jp_r = 0;
        
    else
        
        switch P.BC
            case 0
                jn_l = 0;
                jp_l = 0;
                jn_r = 0;
                jp_r = 0;
                % Blocking contacts
            case 1
                % Setting jp_l = djpdx(end) ensures that jp_r = 0;
                jn_l = 0;
                jp_l = -deltajp(:, end);
                
                jn_r = deltajn(:, end);
                jp_r = 0;
                
            case 2
                
                jn_l = -P.sn_l*(n(:, 1) - P.n0(1));
                jp_l = -deltajp(:, end) + P.sp_r*(p(:, end) - P.p0(end));
                
                jn_r = deltajn(:, end) - P.sn_l*(n(:, 1) - P.n0(1));
                jp_r = P.sp_r*(p(:, end) - P.p0(end));
                
            case 3
                
                jn_l = -P.sn_l*(n(:, 1) - P.n0(1));
                jp_l = -P.sp_l*(p(:, 1) - P.p0(1));
                
                jn_r = P.sn_r*(n(:, end) - P.n0(end));
                jp_r = P.sp_r*(p(:, end) - P.p0(end));
                
        end
    end
    % Calculate total electron and hole currents from fluxes
    jn = jn_l + deltajn;
    jp = jp_l + deltajp;
    
    Jn = -jn*1000*P.e;
    Jp = jp*1000*P.e;
    
    % Total current
    Jtot = Jn + Jp;

% Calculates current at every point and all times - 
% UNRELIABLE FOR TOTAL CURRENT
if P.calcJ == 1

% find the internal current density in the device
Jndiff = zeros(length(t), length(x));
Jndrift = zeros(length(t), length(x));
Jpdiff = zeros(length(t), length(x));
Jpdrift = zeros(length(t), length(x));
Jpart = zeros(length(t), length(x));
Jtot = zeros(length(t));   


for j=1:length(t)
    
    [nloc,dnlocdx] = pdeval(0,x,n(j,:),x);    
    [ploc,dplocdx] = pdeval(0,x,p(j,:),x);
    [iloc,dilocdx] = pdeval(0,x,a(j,:),x);
    [Vloc, dVdx] = pdeval(0,x,V(j,:),x);
    
    % Particle currents
    Jndiff(j,:) = (P.mue_i*P.kB*P.T*dnlocdx)*(1000*P.e);
    Jndrift(j,:) = (-P.mue_i*nloc.*dVdx)*(1000*P.e);
   
    Jpdiff(j,:) = (-P.muh_i*P.kB*P.T*dplocdx)*(1000*P.e);
    Jpdrift(j,:) = (-P.muh_i*ploc.*dVdx)*(1000*P.e);
    
    Jidiff(j,:) = (-P.mui*P.kB*P.T*dilocdx)*(1000*P.e);
    Jidrift(j,:) = (-P.mui*iloc.*dVdx)*(1000*P.e);

    % Particle current
    Jpart(j,:) = Jndiff(j,:) + Jndrift(j,:) + Jpdiff(j,:) + Jpdrift(j,:) + Jidiff(j,:) + Jidrift(j,:);   
    
    % Potential grad
    dVdxt(j,:) = dVdx;
    
end

% Median current- temporary fix to avoid large errors
Jpartr = median(Jpart,2);
Jpartr = Jpartr'; 

% Displacement Current at right hand side
Fend = -(dVdxt(:, end));
Jdispr = (P.e*1000)*P.epp(3)*-gradient(dVdxt(:, end), t);
Jdispr = Jdispr';

end

%Figures
if P.figson == 1
    
    % Open circuit voltage
      if P.OC == 1
        
        figure(7);
        plot (t, Voc);
        xlabel('Time [s]');   
        ylabel('Voltage [V]');

      end

% Dodgy way to change all the graphing but works!
if P.OC == 1
    
    xnmend = round(xnm(end)/2);
    
else
    
    xnmend = xnm(end);
end

%%%%% FIGURES %%%%%

% Band Diagram
FH1 = figure(1);
%set(FigHandle, 'units','normalized','position',[.1 .1 .4 .4]);
PH1 = subplot(3,1,1);
plot (xnm, Efn(end,:), '--', xnm, Efp(end,:), '--', xnm, Ecb(end, :), xnm, Evb(end ,:));
%legend('E_{fn}', 'E_{fp}', 'CB', 'VB');
set(legend,'FontSize',12);
%xlabel('Position [nm]');
ylabel('Energy [eV]'); 
xlim([0, xnmend]);
%ylim([-inf, 0.5]);
set(legend,'FontSize',12);
set(legend,'EdgeColor',[1 1 1]);
grid off;
drawnow;

% Final Charge Densities
%figure(2)
PH2 = subplot(3,1,2);
semilogy(xnm, n(end, :), xnm, p(end, :));
ylabel('{\itn, p} [cm^{-3}]')
%legend('\itn', '\itp')
%xlabel('Position [nm]')
xlim([0, xnmend]);
ylim([1e0, 1e20]);
set(legend,'FontSize',12);
set(legend,'EdgeColor',[1 1 1]);
grid off

PH3 = subplot(3,1,3);
plot(xnm, (a(end,:))/1e19, 'black');
ylabel('{\ita} [x10^{19} cm^{-3}]');
xlabel('Position [nm]');
xlim([0, xnmend]);
ylim([0, 1.1*(max(sol(end,:,3))/1e19)]);
set(legend,'FontSize',12);
set(legend,'EdgeColor',[1 1 1]);
grid off

figure(4)
plot(xnm, Jn(end, :), xnm, Jp(end, :), xnm, Jtot(end, :))
xlabel('Position [nm]')
ylabel('Current density [mAcm-2]')

% % Stacked plot formatting  [left, bottom, width, height] 
% 
% SP2 = get(PH2, 'pos');
% SP2(2) = SP2(4) + 400;
% 
% SP3 = get(PH3, 'pos');
% SP3(2) = SP3(4) + 800;
% 
% figure(5)
% plot(xnm, rhoc(end, :))
% ylabel('Net Charge Density [cm^{-3}]')
% xlabel('Position [nm]')
% xlim([0, xnmend]);
% set(legend,'FontSize',14);
% set(legend,'EdgeColor',[1 1 1]);
% grid off
% 
% figure(6)
% plot(t, ntot, t, ptot)
% ylabel('Charge Density [cm^{-3}]')
% xlabel('time [s]')
% legend('electrons', 'holes')
% set(legend,'FontSize',14);
% set(legend,'EdgeColor',[1 1 1]);
% grid off

% 
% if P.OM == 1 && P.Int~=0 || P.OM == 2 && P.Int~=0
% 
% NOT CURRETN IMPLEMENTED
% genspacenm = genspace * 1e7;
% 
% figure(7);
% plot(genspacenm, Gx1S, genspacenm, GxLas)
% ylabel('Generation Rate [cm^{3}s^{-1}]');
% xlabel('Position [nm]');
% legend('1 Sun', '638 nm');
% xlim([0, genspacenm(end)]);
% grid off
% 
% end

if P.calcJ == 1

figure(8);
plot(xnm,Jndiff(end, :),xnm,Jndrift(end, :),xnm,Jpdiff(end, :),xnm,Jpdrift(end, :),xnm,Jidiff(end, :),xnm,Jidrift(end, :),xnm,Jpart(end, :));
legend('Jn diff','Jn drift','Jp diff','Jp drift','Ji diff','Ji drift','Total J');
xlabel('Position [nm]');
ylabel('Current Density [mA cm^-2]');
set(legend,'FontSize',12);
set(legend,'EdgeColor',[1 1 1]);
xlim([0, xnmend]);
grid off;
drawnow;

%{
% Electric Field
figure(9);
surf(xnm, t, Floct);
xlabel('Position [m]');
ylabel('time [s]');
title('Electric Field');
%}

end

if P.calcJ == 0 || P.calcJ == 1
    
    if P.JV == 1
            %JV
            figure(11)
            plot(Vapp_arr, Jtot(:, end))
            xlabel('V_{app} [V]')
            ylabel('Current Density [mA cm^-2]');
            grid off;

    else
        % Particle and displacement currents as a function of time
    figure(10);
    plot(t, Jtot(:, end));
    legend('Jtotal')
    xlabel('time [s]');
    ylabel('J [mA cm^{-2}]');
    set(legend,'FontSize',16);
    set(legend,'EdgeColor',[1 1 1]);
    grid off;
    drawnow;

    end


end

end

end