%% Test 4: Comparison of multislice and single slice TSE

addpath(genpath('lib'));
addpath(genpath('EPGX-src'));

%%% White matter model (see Gloor 2008)
f = 0.1166;  %% F=0.132 = f/(1-f) => f=0.1166
kf = 4.3e-3;
kb = kf * (1-f)/f;
R1f = 1/779; % ms^-1
R1b = 1/1000; %<- Gloor fix as T1f, usual literature is 1s
R2f = 1/45;


%%% Number of refocusing pulses
nrefocus = 27;

a0={};

%%% have 10 different flips
refocus_angle = 50:10:180;
nangle = length(refocus_angle);

%%% Common sequence parameters
ESP = 7.3;
TR = 5000; %<--- use this to work out time gap at the end

slice_order = [1 3 5 2 4];%<- slice of interest is number 3
soi = 3;%<- slice of interest is number 3

Nsl = length(slice_order);
Ntr = 3;
slice_order = repmat(slice_order,[1 Ntr]);
Ntot = Ntr * Nsl;

%%% now bulk out the shot to include dummy pulses
Tshot = TR/Nsl;
Tdelay = Tshot - ESP*(nrefocus+0.5);
ndummy = round(Tdelay/ESP);

%%% Generate refocusing pulse series as described in Weigel et al, 2010
for jj=1:nangle
    a0{jj} = d2r([90 90+refocus_angle(jj)/2 refocus_angle(jj)*ones(1,nrefocus-1)]);
    if ndummy>0
        a0{jj} = [a0{jj} zeros(1,ndummy)];
    end
end
npulse = length(a0{1}); % same


%% lineshape & slice offset frequencies
T2b=12e-6;
[ff,G] = SuperLorentzian(T2b);
df = 2*[-2 -1 0 1 2]*1e3;

GG = interp1(ff,G,df); %<-- saturation factor for each slice


z0_ms = {};
mz_ms = {};
ss_ms = {};
z0_ss = {};
mz_ss = {};
ss_ss = {};

RFpower = [20 30 40];

for kk = 1:3 %<-- loop over B1 saturation powers
    for jj=1:nangle %<-- loop over flip trains
        
        %%% MT pool saturation depends on flips
        b1sqrdtau = RFpower(kk) * a0{jj}.^2; % ms uT^2
        
        %%% simulate both cases
        z0_ms{jj,kk} = [(1-f) f]; %<-- multi slice
        mz_ms{jj,kk} = zeros([npulse-1 Ntot 2]);
        ss_ms{jj,kk} = zeros([npulse-1 Ntot]);
        z0_ss{jj,kk} = [(1-f) f]; %<-- single slice
        mz_ss{jj,kk} = zeros([npulse-1 Ntot 2]);
        ss_ss{jj,kk} = zeros([npulse-1 Ntot]);
        
        
        
        for ii=1:Ntot
            
            %%% First do multi-slice case
            if slice_order(ii)==soi
                % Local slice
                [s, Fn,Zn] = EPGX_TSE_MT(a0{jj},b1sqrdtau,ESP,[1/R1f 1/R1b],1/R2f,f,kf,GG(soi),'zinit',z0_ms{jj,kk});
            else
                % Other slice
                % set flips to zero and use the saturation lineshape for that slice
                [s, Fn,Zn] = EPGX_TSE_MT(a0{jj}*0,b1sqrdtau,ESP,[1/R1f 1/R1b],1/R2f,f,kf,GG(slice_order(ii)),'zinit',z0_ms{jj,kk});
            end
            % update z0
            z0_ms{jj,kk} = squeeze(Zn(1,end,:));
            mz_ms{jj,kk}(:,ii,:) = reshape(Zn(1,:,:),[npulse-1 1 2]);
            ss_ms{jj,kk}(:,ii) = s;
            
            %%% Now single slice case - off resonant slices do nothing, but Mz evolves still
            if slice_order(ii)==soi
                [s, Fn,Zn] = EPGX_TSE_MT(a0{jj},b1sqrdtau,ESP,[1/R1f 1/R1b],1/R2f,f,kf,GG(soi),'zinit',z0_ss{jj,kk});
            else
                % set flips to zero but keep saturation
                [s, Fn,Zn] = EPGX_TSE_MT(a0{jj}*0,b1sqrdtau*0,ESP,[1/R1f 1/R1b],1/R2f,f,kf,GG(soi),'zinit',z0_ss{jj,kk});
            end
            % update z0
            z0_ss{jj,kk} = squeeze(Zn(1,end,:));
            mz_ss{jj,kk}(:,ii,:) = reshape(Zn(1,:,:),[npulse-1 1 2]);
            ss_ss{jj,kk}(:,ii) = s;
            
        end
        disp([jj kk])
    end
end

%% Find echo amplitudes at echo time (echo number 11)
ms_att = [];
echo_idx = 11; %<-- TE=80ms
idx = 1:27;
soi_idx = min(find(slice_order==soi)); %<- this is the order of the slice of interest in time

for kk=1:3
    for jj=1:nangle
        ms_att(jj,kk)=abs(ss_ms{jj,kk}(idx(echo_idx)+ (npulse-1)*(Nsl*(Ntr-1)+(soi_idx-1))))/abs(ss_ss{jj,kk}(idx(echo_idx)+ (npulse-1)*(Nsl*(Ntr-1)+(soi_idx-1))));
    end
end
%%% Semiempiric model, Weigel 2010
AA = 0.75;
CC = 0.28;
Iratio=[];
for jj=1:nangle
    Iratio(jj) = AA + (1-AA)./(1+CC*(norm(a0{jj})^2/(nrefocus+1)));
end


%% Alternative figure

fs=13;

figure(2)

%%% Only plot the 180 degree, RF power = 30
subplot(2,2,1:2)
i1=14;i2=2;
plot(reshape(mz_ms{i1,i2},[(npulse-1)*Ntot 2]))
hold on
plot(reshape(mz_ss{i1,i2},[(npulse-1)*Ntot 2]),'-.')

legend({'Multi Slice Z_0^a','Multi Slice {Z}_0^{b}',...
    'Single Slice {Z}_0^{a}','Single Slice {Z}_0^{b}'},...
    'location','Eastoutside','FontSize',11)

grid on
xlabel('Excited slice number','fontsize',fs)
ylabel('$$\tilde{Z}_0^{a,b} / M_0$$','interpreter','latex','fontsize',14)


title('M_z over 3 TR periods, RMS flip = 180')

set(gca,'xtick',0:(npulse-1):(npulse-1)*Ntot,'xticklabel',slice_order,'fontsize',fs)
ylim([0 1])
xlim([0 (npulse-1)*Ntot])
%%% patch objects
p1 = [];
p2=[];
for ii=1:Ntr
    for kk=1:Nsl
        if slice_order(kk)==soi
            tmp = patch((npulse-1)*Nsl*(ii-1)+(kk-1)*npulse+[0 nrefocus nrefocus 0],...
                [0 0 1 1],[1 1 1]);
            p1 = [p1 tmp];
        else
            tmp = patch((npulse-1)*Nsl*(ii-1)+(kk-1)*npulse+[0 nrefocus nrefocus 0],...
                [0 0 1 1],[1 1 1]);
            p2 = [p2 tmp];
        end
    end
end
set(p1,'EdgeAlpha',0,'FaceAlpha',0.15,'FaceColor',[1 0 0])
set(p2,'EdgeAlpha',0,'FaceAlpha',0.25,'FaceColor',[0 1 0])


%%% Echo plot
soi_idx = min(find(slice_order==soi)); %<- this is the order of the slice of interest in time

idx = 1:27;

subplot(2,2,3)
plot(abs(ss_ms{i1,i2}(idx + (npulse-1)*(Nsl*(Ntr-1)+(soi_idx-1)))))
hold on
plot(abs(ss_ss{i1,i2}(idx + (npulse-1)*(Nsl*(Ntr-1)+(soi_idx-1)))))
grid on
xlim([1 nrefocus])

title('Echo amplitudes','fontsize',fs)

legend('Multi Slice','Single Slice')
xlabel('Echo number','fontsize',fs)
ylabel('$$\tilde{F}_0 / M_0$$','interpreter','latex','fontsize',14)
echo_idx = 11; %<-- TE=80ms

plot(echo_idx,abs(ss_ms{i1,i2}(idx(echo_idx)+ (npulse-1)*(Nsl*(Ntr-1)+(soi_idx-1)))),'*k')
plot(echo_idx,abs(ss_ss{i1,i2}(idx(echo_idx)+ (npulse-1)*(Nsl*(Ntr-1)+(soi_idx-1)))),'*k')
text(echo_idx,0.4,sprintf('I_{MS}/I_{SS} = %1.2f',abs(ss_ms{i1,i2}(idx(echo_idx)+ (npulse-1)*(Nsl*(Ntr-1)+(soi_idx-1))))/abs(ss_ss{i1,i2}(idx(echo_idx)+ (npulse-1)*(Nsl*(Ntr-1)+(soi_idx-1))))),'fontweight','bold','fontsize',14)

%%% Signal attenutation over all flips
subplot(2,2,4)
plot(refocus_angle,Iratio,'linewidth',2)
hold on
mkr={'o','^','s'};
for ii=1:3
    pp=plot(refocus_angle,ms_att(:,ii),mkr{ii});
    set(pp,'markerfacecolor',get(pp,'color'))
end
grid on
ylim([0.75 1])
xlim([50 180])

title('Multi-slice attenuation factor','fontsize',fs)
legend('Semiempirical model (Weigel, 2010)',...
    '<B_1^2>=20\alpha_{RMS}^2 \muT^2 ms','<B_1^2>=30\alpha_{RMS}^2 \muT^2 ms','<B_1^2>=40\alpha_{RMS}^2 \muT^2 ms')
xlabel('RMS flip angle (deg)','fontsize',fs)
ylabel('I_{MS}/I_{SS}','fontsize',fs)


%
gc = get(gcf,'children');
set(gc(1),'Position',[0.73    0.2829    0.2242    0.1342])
set(gc(2),'Position',[0.52    0.07    0.44    0.35])
set(gc(3),'Position',[0.2999    0.3439    0.1095    0.0514])
set(gc(4),'Position',[0.08    0.07    0.3496    0.35])
set(gc(5),'Position',[0.81    0.6301    0.1399    0.1709])
set(gc(6),'Position',[0.08    0.5441    0.8782    0.3809])

setpospap([110   199   860   483])

axes(gc(6));
fs=18;
text(-150,-0.05,'(a)','fontsize',fs,'fontweight','bold')
text(-150,-1.3,'(b)','fontsize',fs,'fontweight','bold')
text(850,-1.3,'(c)','fontsize',fs,'fontweight','bold')


%
print('-dpng','-r300','bin/Figure9.png')