pipeline {
  agent {
    node {
      label 'maven'
    }
  }
  environment {
    HARBOR_ADDRESS = 'harbor.tianxiang.love'
  }
  parameters {
    string(
      name: 'GIT_BRANCH_NAME',
      defaultValue: 'main',
      description: '请输入要构建的 Git 分支（支持 main/main-/ dev/dev-、pre/pre-、pro/prod/pro-/prod- 前缀自动匹配环境）'
    )

    string(
      name: 'JAR_PATH',
      defaultValue: '',
      description: 'Jar 包相对路径（可选，不填则自动识别，适用于非标准/多模块项目）'
    )

    string(
      name: 'IMAGE_NAME_PARAM',
      defaultValue: '',
      description: 'Docker镜像名称（可选，默认使用Git仓库名称）'
    )

    string(
      name: 'HARBOR_PROJECT_PARAM',
      defaultValue: '',
      description: 'Harbor 项目名（必填，同时也是 POD 部署的 NAMESPACE，不填则使用默认环境变量 HARBOR_PROJECT）'
    )
  }
  stages {
    stage('拉取代码') {
      agent none
      steps {
        container('maven') {
          echo "📥 正在拉取分支: ${params.GIT_BRANCH_NAME}"
          git(url: 'https://k8s-gitlab.tianxiang.love/my-awesome-group/java-demo-project.git', branch: "${params.GIT_BRANCH_NAME}", credentialsId: 'k8s-gitlab-login')
          script {
            env.GIT_COMMIT = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
            echo "✅ 当前 GIT_COMMIT: ${env.GIT_COMMIT}"

            // 动态设置 HARBOR_PROJECT / IMAGE_NAME：优先使用用户参数，其次使用默认/仓库名
            def repoUrl = sh(returnStdout: true, script: 'git config --get remote.origin.url').trim()
            def repoPath = repoUrl
            if (repoUrl.contains('://')) {
              repoPath = repoUrl.split('://', 2)[1]
            }
            if (!repoUrl.contains('://') && repoPath.contains(':')) {
              // 兼容 git@host:group/repo.git
              repoPath = repoPath.split(':', 2)[1]
            }
            def repoName = repoPath.tokenize('/')?.last()
            repoName = repoName?.trim().replaceAll(/\.git$/, '')

            env.HARBOR_PROJECT = params.HARBOR_PROJECT_PARAM?.trim() ? params.HARBOR_PROJECT_PARAM.trim() : env.HARBOR_PROJECT
            env.IMAGE_NAME = params.IMAGE_NAME_PARAM?.trim() ? params.IMAGE_NAME_PARAM.trim() : repoName

            if (!env.IMAGE_NAME?.trim()) {
              error "无法推断 IMAGE_NAME（repoUrl=${repoUrl}），请在参数 IMAGE_NAME 中手动指定"
            }

            echo "📦 最终镜像信息: HARBOR_PROJECT=${env.HARBOR_PROJECT}, IMAGE_NAME=${env.IMAGE_NAME}"
          }

        }

      }
    }

    stage('构建Jar包') {
      agent none
      steps {
        container('maven') {
          script {
            // 1️⃣ 确定 Maven Profile（根据分支前缀推断的环境）
            def branch = params.GIT_BRANCH_NAME?.trim()
            String deployEnv
            if (branch ==~ /^dev(-.*)?$/) {
              deployEnv = 'dev'
            } else if (branch ==~ /^pre(-.*)?$/) {
              deployEnv = 'pre'
            } else if (branch ==~ /^(pro|prod|main)(-.*)?$/) {
              deployEnv = 'prod'
            } else {
              error "无法根据 GIT_BRANCH_NAME='${branch}' 推断部署环境，请使用 dev/dev-、pre/pre-、main/main-、pro/prod/pro-/prod- 作为前缀"
            }

            def mvnProfile = (deployEnv == 'prod') ? 'prod' : 'dev'
            echo "🏗️ 使用 Maven Profile: ${mvnProfile}"

            // 2️⃣ Maven 构建
            sh "mvn -B clean package -P ${mvnProfile} -Dmaven.test.skip=true"

            echo "📦 确定 Jar 构建产物..."

            // 3️⃣ 优先使用用户指定的 JAR_PATH
            if (params.JAR_PATH?.trim()) {
              env.JAR_PATH = params.JAR_PATH.trim()

              if (!fileExists(env.JAR_PATH)) {
                error "❌ 指定的 JAR_PATH 不存在: ${env.JAR_PATH}"
              }

              echo "✅ 使用用户指定 Jar: ${env.JAR_PATH}"
            }
           // 4️⃣ Maven 官方方式解析（推荐：基于 buildDir + glob）
           else {
             // 4.1 获取 Maven 构建目录
             def buildDir = sh(
               returnStdout: true,
               script: 'mvn -q help:evaluate -Dexpression=project.build.directory -DforceStdout 2>/dev/null || true'
             ).trim()

             echo "📂 Maven buildDir: ${buildDir}"

             // 4.2 在 buildDir 中查找可用 Jar（排除 sources / javadoc / original）
             def jarInBuildDir = ''
             if (buildDir) {
               jarInBuildDir = sh(
                 returnStdout: true,
                 script: """
                   ls -1 ${buildDir}/*.jar 2>/dev/null \
                     | grep -vE '(sources|javadoc|original)' \
                     | head -n 1 || true
                 """
               ).trim()
             }

             if (jarInBuildDir && fileExists(jarInBuildDir)) {
               env.JAR_PATH = jarInBuildDir
               echo "✅ 使用 Maven 构建产物: ${env.JAR_PATH}"
             }
             // 5️⃣ 兜底：全仓库扫描（多模块 / 非标准）
             else {
               echo "🔄 Maven 目录解析失败，执行全仓库扫描..."

               env.JAR_PATH = sh(
                 returnStdout: true,
                 script: '''
                   find . -type f -name "*.jar" \
                     ! -name "*-sources.jar" \
                     ! -name "*-javadoc.jar" \
                     ! -name "original-*.jar" \
                   | xargs ls -lh \
                   | sort -k5 -h \
                   | tail -n 1 \
                   | awk '{print $NF}'
                 '''
               ).trim()

               if (!env.JAR_PATH || !fileExists(env.JAR_PATH)) {
                 error "❌ 无法自动识别 Jar 包"
               }

               echo "✅ 自动识别主 Jar: ${env.JAR_PATH}"
             }
           }

            // 6️⃣ 最终确认（方便排障）
            sh "ls -lh ${env.JAR_PATH}"
          }
        }

      }
    }

    stage('生成TAG标签') {
      agent none
      steps {
        container('maven') {
          script {
            def dateTag = sh(returnStdout: true, script: 'date +%Y-%m-%d-%H-%M').trim()
            env.TAG_NAME = "${params.GIT_BRANCH_NAME}-${dateTag}-${env.GIT_COMMIT}-${BUILD_NUMBER}"
            echo "✅ 生成的 TAG_NAME: ${env.TAG_NAME}"
          }

        }

      }
    }

    stage('Docker Build & Push 镜像') {
      agent none
      steps {
        container('maven') {
          // 1. 首先计算相对路径
          script {
            def jarRelativePath = sh(
              returnStdout: true,
              script: "realpath --relative-to=. ${env.JAR_PATH}"
            ).trim()
            env.JAR_RELATIVE_PATH = jarRelativePath
            echo "📦 Docker JAR_FILE 参数: ${jarRelativePath}"
          }

          // 2. 使用 withCredentials 进行 Docker 操作
          withCredentials([usernamePassword(
            credentialsId: 'harbor-credentials',
            usernameVariable: 'HARBOR_USER',
            passwordVariable: 'HARBOR_PASSWD'
          )]) {
            sh '''
              echo "登录 Harbor 仓库"
              echo "$HARBOR_PASSWD" | docker login $HARBOR_ADDRESS -u "$HARBOR_USER" --password-stdin
            '''

            sh """
              echo "构建镜像: $HARBOR_ADDRESS/$HARBOR_PROJECT/$IMAGE_NAME:${TAG_NAME}"
              docker build -t $HARBOR_ADDRESS/$HARBOR_PROJECT/$IMAGE_NAME:${TAG_NAME} --build-arg JAR_FILE=${JAR_RELATIVE_PATH} .
            """

            sh """
              echo "推送镜像中..."
              docker push $HARBOR_ADDRESS/$HARBOR_PROJECT/$IMAGE_NAME:${TAG_NAME}
              echo "✅ 镜像推送成功: $HARBOR_ADDRESS/$HARBOR_PROJECT/$IMAGE_NAME:${TAG_NAME}"
            """
          }
        }
      }
    }

    stage('确认 k8s 环境') {
      agent none
      steps {
        container('maven') {
          script {
            def branch = params.GIT_BRANCH_NAME?.trim()
            if (branch ==~ /^dev(-.*)?$/) {
              env.DEPLOY_PROFILE = 'dev'
            } else if (branch ==~ /^pre(-.*)?$/) {
              env.DEPLOY_PROFILE = 'pre'
            } else if (branch ==~ /^(pro|prod|main)(-.*)?$/) {
              env.DEPLOY_PROFILE = 'prod'
            } else {
              error "无法根据 GIT_BRANCH_NAME='${branch}' 推断部署环境，请使用 dev/dev-、pre/pre-、main/main-、pro/prod/pro-/prod- 作为前缀"
            }

            switch(env.DEPLOY_PROFILE) {
              case 'dev': env.KUBECONFIG_CREDENTIALS_ID = 'dev-kubeconfig'; break
              case 'pre': env.KUBECONFIG_CREDENTIALS_ID = 'pre-kubeconfig'; break
              case 'prod': env.KUBECONFIG_CREDENTIALS_ID = 'prod-kubeconfig'; break
            }
            env.DEPLOY_TEMPLATE = "k8s/deployment-${env.DEPLOY_PROFILE}.tml"

            echo "🚀 开始部署到 ${env.DEPLOY_PROFILE} 环境"
            echo "📦 使用模板: ${env.DEPLOY_TEMPLATE}"
            echo "🔑 使用 KubeConfig 凭据: ${env.KUBECONFIG_CREDENTIALS_ID}"
          }

        }

      }
    }

    stage('配置 K8s 环境') {
      agent none
      steps {
        container('maven') {
          withCredentials([kubeconfigContent(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: 'KUBECONFIG_CONTENT')]) {
            sh '''echo "🔧 配置 K8s 环境..."
                            mkdir -p ~/.kube
                            echo "$KUBECONFIG_CONTENT" > ~/.kube/config
                            chmod 600 ~/.kube/config
                            echo '192.168.233.246 apiserver.cluster.local' | tee -a /etc/hosts

                            echo "✅ KubeConfig 配置完成"

                            if kubectl cluster-info > /dev/null 2>&1; then
                                echo "✅ K8s 集群连接正常"
                                kubectl cluster-info
                            else
                                echo "❌ K8s 集群连接失败"
                                exit 1
                            fi'''
          }

        }

      }
    }

    stage('渲染部署文件') {
      agent none
      steps {
        container('maven') {
          sh '''
                        echo "🎨 渲染部署文件..."
                        sed -e "s/{{.IMAGE_NAME}}/${IMAGE_NAME}/g" \
                            -e "s/{{.PROJECT_NAME}}/${HARBOR_PROJECT}/g" \
                            -e "s/{{.TAG_NAME}}/${TAG_NAME}/g" \
                            -e "s/{{.HARBOR_ADDRESS}}/${HARBOR_ADDRESS}/g" \
                            -e "s/{{.PROFILE}}/${DEPLOY_PROFILE}/g" \
                            ${DEPLOY_TEMPLATE} > k8s/deployment-"${DEPLOY_PROFILE}".yaml

                        echo "📄 生成的部署文件内容:"
                        cat k8s/deployment-"${DEPLOY_PROFILE}".yaml
                        echo "✅ 部署文件渲染完成"
                    '''
        }

      }
    }

    stage('应用部署') {
      agent none
      steps {
        container('maven') {
          sh '''
                        echo "🚀 开始应用部署..."
                        DEPLOY_START_TIME=$(date +%s)
                        echo "DEPLOY_START_TIME=$DEPLOY_START_TIME" > /tmp/deploy_time.env
                        kubectl apply -f k8s/deployment-"${DEPLOY_PROFILE}".yaml
                        echo "✅ 部署文件应用完成"
                    '''
        }

      }
    }

    stage('等待 Pod 就绪') {
      agent none
      steps {
        container('maven') {
          sh '''
                chmod +x ./scripts/wait-pod-running.sh
                bash ./scripts/wait-pod-running.sh "${HARBOR_PROJECT}" "${IMAGE_NAME}"
                    '''
        }

      }
    }

  }
}