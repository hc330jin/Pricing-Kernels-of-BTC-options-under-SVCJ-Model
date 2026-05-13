
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd

def simulate_svcj(params, T, dt=1):
    """
    根據 SVCJ 參數模擬一條價格路徑
    params: 字典，包含 mu, kappa, theta, sigmav, rho, lambda_, mu_y, sigma_y, mu_v
    T: 模擬天數
    """
    # 提取參數
    mu = params['mu']
    beta = params['beta']
    alpha = params['alpha']
    sigmav = params['sigmav']
    rho = params['rho']
    lam = params['lambda_']
    mu_y = params['mu_y']
    sigma_y = params['sigma_y']
    mu_v = params['mu_v']
    
    # 初始化
    returns = np.zeros(T)
    vol = np.zeros(T)
    vol[0] = -alpha/beta # 初始波動率設為長期均值
    
    for t in range(1, T):
        # 相關標準正態隨機數
        z1 = np.random.normal(0, 1)
        z2 = np.random.normal(0, 1)
        zv = z1
        zy = rho * z1 + np.sqrt(1 - rho**2) * z2
        
        # 判斷是否發生跳躍 (Poisson process)
        jump_occurrence = np.random.poisson(lam * dt)
        J_y = 0
        J_v = 0
        if jump_occurrence > 0:
            # 波動率跳躍 (Exponential)
            J_v = np.random.exponential(mu_v)
            # 價格跳躍 (Normal, 且與波動率跳躍可能相關，此處簡化)
            J_y = np.random.normal(mu_y, sigma_y)
        
        # 波動率方程 (CIR process + Jump)
        vol_drift = (alpha + beta * vol[t-1]) * dt
        vol_diffusion = sigmav * np.sqrt(max(0, vol[t-1] * dt)) * zv
        vol[t] = max(1e-9, vol[t-1] + vol_drift + vol_diffusion + J_v)
        '''vol[t] = max(1e-5, vol[t-1] + kappa * (theta - vol[t-1]) * dt + 
                     sigmav * np.sqrt(max(0, vol[t-1] * dt)) * zv + J_v)'''
        
        # 報酬率方程
        returns[t] = (mu - 0.5 * vol[t-1]) * dt + np.sqrt(vol[t-1] * dt) * zy + J_y

    return returns

# --- 驗證邏輯 ---

# 1. 輸入你 MCMC 跑出來的估計值
N=20000
s="BTC"
i=1
file_path=f'SVCJ_{N}estimate_{s}_{i}/sum.csv'
df=pd.read_csv(file_path)
mu=df["mu"].values
estimated_params = {
    'mu': df["mu"].values, 'beta': df["beta"].values, 'alpha': df["alpha"].values, 'sigmav': df["sigma2_v"].values, 
    'rho': df["rho"].values, 'lambda_': df["lambda"].values, 'mu_y': df["mu_y"].values, 'sigma_y':df["sigma2_y"].values+5,
    'mu_v': df["mu_v"].values
}

# 2. 進行後驗模擬 (模擬 T 天，建議與你原始數據長度一致)
T_len = 4293 
sim_returns = simulate_svcj(estimated_params, T_len)

# 2.5 Return
file_path=f'SVCJ_{N}estimate_{s}_{i}/return.csv'
df=pd.read_csv(file_path, header=None)
real_returns=df.iloc[:,1].to_numpy()

# 3. 視覺化對比：模擬 vs 真實 (假設你已有 real_returns)
# 
plt.figure(figsize=(12, 6))
sns.kdeplot(sim_returns, label='Simulated (Post-MCMC)', color='blue', shade=True)
sns.kdeplot(real_returns, label='Real Market Data', color='red') # 取消註釋放入真數據
plt.title("Posterior Predictive Check: Return Distribution")
plt.xlabel("Returns")
plt.legend()
plt.show()

# 4. 關鍵統計量檢查
print(f"模擬偏態 (Skewness): {np.mean((sim_returns - np.mean(sim_returns))**3)}")
print(f"模擬峰度 (Kurtosis): {np.mean((sim_returns - np.mean(sim_returns))**4)}")