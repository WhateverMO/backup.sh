中文 | [English](README.md)

# 文件夹同步备份系统

一个极简、零依赖的文件夹同步系统，采用**纯增量备份策略**。

## 核心原则

**这是一个单向备份系统**：

- ✅ **复制**：将源目录的新文件复制到目标目录
- ✅ **更新**：将源目录的已更改文件更新到目标目录
- ❌ **不删除**：不会从目标目录删除文件（即使源目录已删除）
- ❌ **不同步删除**：任何方向的删除操作都不会同步

## 如何编写配置文件

### 配置格式 (`sync.conf`)

```
源路径:目标路径:频率
```

### 示例

**示例1：绝对目标路径**

```
/home/user/documents:/backup/documents:1h
```

**示例2：相对目标路径**（存放在 `data/` 文件夹下）

```
/home/user/photos:my-photos:1d
# 目标路径变为：/项目路径/data/my-photos/
```

**示例3：多个同步任务**

```
/home/user/work:work-backup:30m
/home/user/music:music-backup:1d
/etc:system-config:1w
```

### 频率单位

- `s` - 秒 (如：`30s`)
- `m` - 分钟 (如：`5m`, `30m`)
- `h` - 小时 (如：`1h`, `6h`)
- `d` - 天 (如：`1d`, `7d`)
- `w` - 周 (如：`1w`, `2w`)

## 各脚本使用场景

### 1. `sync.sh` - 单次同步

**适用场景**：想手动运行一次备份

```bash
./sync.sh
```

- 执行 `sync.conf` 中定义的所有同步任务
- 遵守频率设置
- 输出到 `sync.log`

### 2. `daemon.sh` - 持续后台同步

**适用场景**：登录期间需要自动备份

```bash
./daemon.sh           # 前台运行
./daemon.sh &         # 后台运行
fg                    # 回到前台
```

- 每60秒运行一次 `sync.sh`
- 持续运行直到手动停止
- 适合开发/测试环境

### 3. `install-cron.sh` - 永久定时同步

**适用场景**：需要可靠的计划备份（推荐生产使用）

```bash
./install-cron.sh
```

- 添加每分钟运行的定时任务
- 即使登出也会继续运行
- 生产环境最可靠

### 4. `uninstall-cron.sh` - 取消定时同步

**适用场景**：想停止自动备份

```bash
./uninstall-cron.sh
```

- 移除定时任务
- 不会删除已备份的文件

## 快速开始

1. **创建配置文件**：

   ```bash
   cp sync.conf.tmplt sync.conf
   vi sync.conf
   ```

2. **添加同步规则**：

   ```
   /Users/yourname/Documents:doc-backup:1h
   ```

3. **测试**：

   ```bash
   ./sync.sh
   tail -f sync.log
   ```

4. **设置自动化**：

   ```bash
   ./install-cron.sh   # 推荐：永久定时任务
   ```

## 常见问题

**Q: 源目录删除文件后，备份目录文件还在吗？**
A: 在，本系统是增量备份，不会删除目标目录的任何文件。

**Q: 如何修改同步频率？**
A: 编辑 `sync.conf` 文件的第三部分（如 `1h` 改为 `30m`）

**Q: 日志文件在哪里？**
A: 项目根目录下的 `sync.log`

**Q: 如何查看正在同步的任务？**
A: 查看 `.sync_state/` 目录中的状态文件
