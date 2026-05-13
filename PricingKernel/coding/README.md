
# 程式碼
### my_self.m
* 每個參數初始值
* 使用到1_step.csv:儲存V, sigV, rho, V0抽樣所需步長，詳細看下面
* 使用到jumpDate_{資產}.csv:J的初始值，全改成0應該沒差

### aaa.m
* 主程式
* 變數注意
  - control.num_MCMC: 迭代次數
  - BTC_prices: 根據所需資料更改行數
  - steps: 資料長度
  - s: 資產
  - MySelf: 來自my_self.m
* 使用到的函數
  - load_real_data.m
  - define_flag.m
  - define_param.m
  - my_self.m
  - run_MCMC.m


### calc_log_likelihood.m
- 原本是算L(Y|V)，現在多乘P(V)，變成L(Y, V)
- 我可能有錯，詳細參考Wendy論文P.61

### run_MCMC.m
- 更改程式碼:J, ZV, ZY, sigV
- 原本sigV用independent MH，現在改用random walk MH

# CSV檔
### 1_steps.csv

### jumpDate_{資產}.csv

### whole_data.csv

# PY檔
