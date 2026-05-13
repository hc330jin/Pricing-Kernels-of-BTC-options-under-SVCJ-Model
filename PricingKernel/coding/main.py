
import csv
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import scipy.stats as stats
from statsmodels.graphics.tsaplots import plot_acf, plot_pacf
from statsmodels.tsa.stattools import acf, pacf


def get_svcj_residuals(Y, V, V0, ZY, ZV, J, mu, alpha, beta, sig2V, dt):
    # 建立 V_t (V_prev)
    V_prev = np.insert(V[:-1], 0, V0)
    
    # 1. Returns Residuals (收益率殘差)
    # 分子：觀測到的 Y 扣除 漂移項 與 跳躍項
    y_expected = mu * dt + ZY * J
    y_resid_raw = Y - y_expected
    # 分母：隨機波動率的標準差
    y_resid_std = y_resid_raw /np.sqrt(V_prev * dt)
    print( y_resid_raw)
    print((V_prev * dt))
    
    # 2. Volatility Residuals (波動率殘差)
    # 分子：V 的增量 扣除 漂移項 與 跳躍項
    '''v_diff = V - V_prev
    
    v_drift = (alpha  + beta * V_prev) * dt + ZV * J
    v_resid_raw = v_diff - v_drift
    # 分母：波動率過程的擴散項標準差
    v_resid_std = v_resid_raw / np.sqrt(sig2V * V_prev * dt)'''
    
    return y_resid_std, y_expected

data=[]
with open('return.csv', newline='') as file:
    origin_data=csv.reader(file, delimiter=' ', quotechar='|')
    for row in origin_data:
        print(row)        
        this=row[1].split(',')
        
        data.append(float(this[1]))
print(data)
#prices=load_real_data(data)

BTC_prices = np.array(data)
BTC_prices=np.maximum(BTC_prices, 1E-08)
Returns= np.diff(np.log(BTC_prices))
Volatility = np.std(Returns)**2

Y=data


df1 = pd.read_csv('sum.csv')

# 計算後驗均值 (Posterior Means)
m_post = df1["mu"].values[0] 
alpha_post = df1["alpha"].values[0]
beta_post = df1["beta"].values[0] 
sigV_post = df1["sigma_v"].values[0] 
V0_post = df1["V0"].values[0] 
muy_post=df1["mu_y"].values[0]
sigy_post=df1["sigma_y"].values[0]
lambda1_post=df1["lambda"].values[0]
rho_post=df1["rho"].values[0]
rhoJ_post=df1["rho_j"].values[0]
muv_post=df1["mu_v"].values[0]

# 隱含變量路徑：通常使用最後一條採樣路徑 (Vsum 可能是路徑累加，也可取平均)
df2 = pd.read_csv('trace.csv')
V_path = ((df2["V"].values))
J_path = df2["J"].values
ZY_path = df2["ZY"].values
ZV_path = df2["ZV"].values
# 使用後驗均值計算殘差

res_y, y_prev = get_svcj_residuals(Y, V_path, V0_post, ZY_path, ZV_path, J_path, 
                                 m_post, alpha_post, beta_post, sigV_post, 1)
#res_y=get_svj_residuals(Y, V_path, J_path, muy_post, sigy_post, lambda1_post)
print(res_y)


folder_name=f'residual'
if not os.path.exists(folder_name):
    os.makedirs(folder_name)

# 2. 繪製殘差診斷圖
#plt.figure(figsize=(12, 8))

# 子圖 1: 收益率殘差時序圖 (應看起來像白噪聲)
#plt.subplot(2, 2, 1)
file_name='Return Residuals.png'
file_path=os.path.join(folder_name, file_name)
plt.plot(res_y, lw=0.5)
plt.title("Standardized Return Residuals ($\epsilon^y$)")
plt.savefig(file_path, transparent=True)
plt.close()
plt.show()
# 子圖 2: 收益率殘差 QQ-Plot (檢查正態性)
#plt.subplot(2, 2, 2)
file_name='QQPlot.png'
file_path=os.path.join(folder_name, file_name)
stats.probplot(res_y, dist="norm", plot=plt)
plt.title("QQ-Plot: Return Residuals")
plt.savefig(file_path, transparent=True)
plt.close()
plt.show()
# 子圖 3: 波動率殘差時序圖
'''plt.subplot(2, 2, 3)
plt.plot(res_v, lw=0.5, color='orange')
plt.title("Standardized Volatility Residuals ($\epsilon^v$)")'''

'''# 子圖 4: 殘差直方圖
plt.subplot(2, 2, 4)
plt.hist(res_y, bins=50, density=True, alpha=0.6, range=(-5, 5), label='$\epsilon^y$')
# 疊加標準正態分佈曲線
#x = np.linspace(-4, 4, 100)
#plt.plot(x, stats.norm.pdf(x, 0, 1), 'r-', lw=2)
#plt.title("Histogram of Residuals")

plt.tight_layout()
plt.show()'''

#plt.subplot(2, 2, 3) 
file_name='distribution.png'
file_path=os.path.join(folder_name, file_name)   
# 1. 繪製直方圖 (密度化)
# 我們設定 range=(-5, 5) 以避免被少數極端離群值拉扁圖表
n, bins, patches = plt.hist(res_y, bins=60,  density=True, range=(-5, 5), 
                            color='#3498db', edgecolor='white',
                            label='Standardized Residuals')

# 2. 計算標準正態分佈的 PDF (用於對照)
x = np.linspace(-5, 5, 200)
pdf = stats.norm.pdf(x, 0, 1)

# 3. 繪製正態分佈曲線
plt.plot(x, pdf, 'r-', lw=2, label='Normal(0,1) Reference')

# 4. 加上統計資訊 (Mean, Std, Skewness, Kurtosis)
mu, sigma = np.mean(res_y), np.std(res_y)
skew = stats.skew(res_y)
kurt = stats.kurtosis(res_y)
jb_statistic, p_value = stats.jarque_bera(res_y)


stats_text = f'Mean: {mu:.2f}\nStd: {sigma:.2f}\nSkew: {skew:.2f}\nKurt: {kurt:.2f}\nJB-test: {jb_statistic:.2f} p_value: {p_value:.2f}'
plt.annotate(stats_text, xy=(0.05, 0.7), xycoords='axes fraction', 
             bbox=dict(boxstyle="round", fc="white", alpha=0.5))

# 圖表格式美化
plt.title('Distribution of Return Residuals ($\epsilon^y$)', fontsize=14)
plt.xlabel('Standardized Residual Value')
plt.ylabel('Density')
plt.grid(axis='y', alpha=0.3)
plt.legend()
plt.savefig(file_path, transparent=True)
plt.close()
plt.show()

#ACF,PACF
file_name='ACF_residual.png'
file_path=os.path.join(folder_name, file_name)
plot_acf(res_y, lags=20)
plt.title("ACF ($\hat{\epsilon}_t$)")
plt.savefig(file_path, transparent=True)
plt.close()
plt.show()

file_name='ACF_squared_residual.png'
file_path=os.path.join(folder_name, file_name)
plot_acf(res_y**2, lags=20)
plt.title("ACF ($\hat{\epsilon}_t^2$)")
plt.savefig(file_path, transparent=True)
plt.close()
plt.show()

file_name='PACF_residual.png'
file_path=os.path.join(folder_name, file_name)
plot_pacf(res_y, lags=20)
plt.title("PACF ($\hat{\epsilon}_t$)")
plt.savefig(file_path, transparent=True)
plt.close()
plt.show()

file_name='PACF_squared_residual.png'
file_path=os.path.join(folder_name, file_name)
plot_pacf(res_y**2, lags=20)
plt.title("PACF ($\hat{\epsilon}_t^2$)")
plt.savefig(file_path, transparent=True)
plt.close()
plt.show()