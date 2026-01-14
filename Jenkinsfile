pipeline {
  agent {
    node {
      label 'maven'
    }
  }
  environment {
    HARBOR_ADDRESS = 'harbor.tiexue.net'
  }
  parameters {
    string(
      name: 'GIT_REF',
      defaultValue: 'main',
      description: '请输入要构建的 Git 分支（支持 main/main-/ dev/dev-、pre/pre-、pro/prod/pro-/prod- 前缀自动匹配环境）'
    )

    string(
      name: 'JAR_PATH',
      defaultValue: '',
      description: 'Jar 包相对路径（可选，不填则自动识别，适用于非标准/多模块项目）'
    )

    string(
      name: 'IMAGE_NAME',
      defaultValue: '',
      description: 'Docker镜像名称（可选，默认使用Git仓库名称）'
    )

    string(
      name: 'IMAGE_PROJECT',
      defaultValue: 'first-project',
      description: 'Harbor 镜像项目名（必填，仅用于镜像仓库）'
    )

    string(
      name: 'K8S_NAMESPACE',
      defaultValue: 'dev-first-project',
      description: 'K8s Namespace（可选，不填默认与 IMAGE_PROJECT 相同）'
    )

    string(
      name: 'HELM_RELEASE',
      defaultValue: '',
      description: 'Helm Release 名称（实例名，不填默认使用 IMAGE_NAME，可用于同 chart 多实例）'
    )

  }
  stages {
    stage('拉取代码') {
      agent none
      steps {
        container('maven') {
          echo "📥 正在拉取分支: ${params.GIT_REF}"
          git(url: 'https://gitlab.tiexue.net/my-awesome-group/java-demo-project.git', branch: "${params.GIT_REF}", credentialsId: 'gitlab-login')
          script {
            env.GIT_COMMIT = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
            echo "✅ 当前 GIT_COMMIT: ${env.GIT_COMMIT}"

            // 动态设置镜像项目/镜像名/命名空间/Helm Release：优先用户参数，其次默认/仓库名
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

            env.IMAGE_PROJECT = params.IMAGE_PROJECT?.trim() ? params.IMAGE_PROJECT.trim() : (env.IMAGE_PROJECT ?: env.HARBOR_PROJECT)
            env.IMAGE_NAME = params.IMAGE_NAME?.trim() ? params.IMAGE_NAME.trim() : repoName
            env.K8S_NAMESPACE = params.K8S_NAMESPACE?.trim() ? params.K8S_NAMESPACE.trim() : (env.IMAGE_PROJECT ?: repoName)

            if (!env.IMAGE_NAME?.trim()) {
              error "无法推断 IMAGE_NAME（repoUrl=${repoUrl}），请在参数 IMAGE_NAME 中手动指定"
            }
            if (!env.IMAGE_PROJECT?.trim()) {
              error "IMAGE_PROJECT 为空：请填写参数 IMAGE_PROJECT（镜像仓库项目）"
            }
            if (!env.K8S_NAMESPACE?.trim()) {
              env.K8S_NAMESPACE = env.IMAGE_PROJECT
            }

            env.HELM_RELEASE = params.HELM_RELEASE?.trim() ? params.HELM_RELEASE.trim() : env.IMAGE_NAME
            echo "📦 最终镜像信息: IMAGE_PROJECT=${env.IMAGE_PROJECT}, IMAGE_NAME=${env.IMAGE_NAME}"
            echo "📂 部署命名空间: ${env.K8S_NAMESPACE}"
            echo "⎈ Helm Release: ${env.HELM_RELEASE}"
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
            def branch = params.GIT_REF?.trim()
            String deployEnv
            if (branch ==~ /^dev(-.*)?$/) {
              deployEnv = 'dev'
            } else if (branch ==~ /^pre(-.*)?$/) {
              deployEnv = 'pre'
            } else if (branch ==~ /^(pro|prod|main)(-.*)?$/) {
              deployEnv = 'prod'
            } else {
              error "无法根据 GIT_REF='${branch}' 推断部署环境，请使用 dev/dev-、pre/pre-、main/main-、pro/prod/pro-/prod- 作为前缀"
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
              def buildDir = sh(
                returnStdout: true,
                script: 'mvn -q help:evaluate -Dexpression=project.build.directory -DforceStdout 2>/dev/null || true'
              ).trim()

              echo "📂 Maven buildDir: ${buildDir}"

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
            env.TAG_NAME = "${params.GIT_REF}-${dateTag}-${env.GIT_COMMIT}-${BUILD_NUMBER}"
            echo "✅ 生成的 TAG_NAME: ${env.TAG_NAME}"
          }
        }
      }
    }

    stage('Docker Build & Push 镜像') {
      agent none
      steps {
        container('maven') {
          script {
            def jarRelativePath = sh(
              returnStdout: true,
              script: "realpath --relative-to=. ${env.JAR_PATH}"
            ).trim()
            env.JAR_RELATIVE_PATH = jarRelativePath
            echo "📦 Docker JAR_FILE 参数: ${jarRelativePath}"
          }

          withCredentials([usernamePassword(
            credentialsId: 'harbor-login',
            usernameVariable: 'HARBOR_USER',
            passwordVariable: 'HARBOR_PASSWD'
          )]) {
            sh '''
              echo "登录 Harbor 仓库"
              echo "$HARBOR_PASSWD" | docker login $HARBOR_ADDRESS -u "$HARBOR_USER" --password-stdin
            '''

            sh """
              echo "构建镜像: $HARBOR_ADDRESS/$IMAGE_PROJECT/$IMAGE_NAME:${TAG_NAME}"
              docker build -t $HARBOR_ADDRESS/$IMAGE_PROJECT/$IMAGE_NAME:${TAG_NAME} --build-arg JAR_FILE=${JAR_RELATIVE_PATH} .
            """

            sh """
              echo "推送镜像中..."
              docker push $HARBOR_ADDRESS/$IMAGE_PROJECT/$IMAGE_NAME:${TAG_NAME}
              docker rmi $HARBOR_ADDRESS/$IMAGE_PROJECT/$IMAGE_NAME:${TAG_NAME}
              echo "✅ 镜像推送成功: $HARBOR_ADDRESS/$IMAGE_PROJECT/$IMAGE_NAME:${TAG_NAME}"
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
            def branch = params.GIT_REF?.trim()
            if (branch ==~ /^dev(-.*)?$/) {
              env.DEPLOY_PROFILE = 'dev'
            } else if (branch ==~ /^pre(-.*)?$/) {
              env.DEPLOY_PROFILE = 'pre'
            } else if (branch ==~ /^(pro|prod|main)(-.*)?$/) {
              env.DEPLOY_PROFILE = 'prod'
            } else {
              error "无法根据 GIT_REF='${branch}' 推断部署环境，请使用 dev/dev-、pre/pre-、main/main-、pro/prod/pro-/prod- 作为前缀"
            }

            switch(env.DEPLOY_PROFILE) {
              case 'dev': env.KUBECONFIG_CREDENTIALS_ID = 'dev-kubeconfig'; break
              case 'pre': env.KUBECONFIG_CREDENTIALS_ID = 'pre-kubeconfig'; break
              case 'prod': env.KUBECONFIG_CREDENTIALS_ID = 'prod-kubeconfig'; break
            }
            echo "🚀 开始部署到 ${env.DEPLOY_PROFILE} 环境（Helm）"
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

    stage('Helm 部署') {
      agent none
      steps {
        container('maven') {
          sh '''
            set -euo pipefail
            set +x

            CHART_SRC_DIR="chart"
            if [ ! -f "${CHART_SRC_DIR}/Chart.yaml" ]; then
              echo "❌ 未找到 Helm Chart：${CHART_SRC_DIR}/Chart.yaml"
              exit 1
            fi

            # 如果提供了 HELM_RELEASE，则动态修改 Chart.yaml 中的 name 字段
            if [ -n "${HELM_RELEASE}" ]; then
                # 备份原始 Chart.yaml
                if [ -f "${CHART_SRC_DIR}/Chart.yaml" ]; then
                    # 使用 sed 直接修改 name 字段
                    sed -i "s/^name:.*$/name: ${HELM_RELEASE}/" "${CHART_SRC_DIR}/Chart.yaml"
                fi
            fi

            # 解析修改后的 Chart.yaml
            CHART_NAME="$(awk -F': *' '/^name:/{print $2; exit}' "${CHART_SRC_DIR}/Chart.yaml" | tr -d '\r' | xargs)"
            if [ -z "${CHART_NAME}" ]; then
                echo "❌ 无法从 Chart.yaml 解析 chart name"
                exit 1
            fi

            # helm lint 要求：目录名必须和 Chart.yaml 的 name 一致
            CHART_DIR="/tmp/${CHART_NAME}"
            rm -rf "${CHART_DIR}"
            mkdir -p "${CHART_DIR}"
            cp -R "${CHART_SRC_DIR}/." "${CHART_DIR}/"

            NAMESPACE="${K8S_NAMESPACE}"
            RELEASE_NAME="${HELM_RELEASE}"
            IMAGE_REPO="${HARBOR_ADDRESS}/${IMAGE_PROJECT}/${IMAGE_NAME}"
            IMAGE_TAG="${TAG_NAME}"

            echo "⎈ chart=${CHART_NAME}, release=${RELEASE_NAME}, ns=${NAMESPACE}"
            echo "🖼️  image=${IMAGE_REPO}:${IMAGE_TAG}"

            # 确保 namespace 存在
            kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

            # values 组合：存在 values-${DEPLOY_PROFILE}.yaml 时自动叠加
            VALUES_ARGS="-f ${CHART_DIR}/values.yaml"
            if [ -f "${CHART_DIR}/values-${DEPLOY_PROFILE}.yaml" ]; then
              VALUES_ARGS="${VALUES_ARGS} -f ${CHART_DIR}/values-${DEPLOY_PROFILE}.yaml"
              echo "📄 使用环境 values: ${CHART_DIR}/values-${DEPLOY_PROFILE}.yaml"
            fi

            echo "🔍 Helm lint..."
            helm3 lint "${CHART_DIR}" ${VALUES_ARGS} \
              --set deploy.image.repository="${IMAGE_REPO}" \
              --set deploy.image.tag="${IMAGE_TAG}"

            FULL_HELM3_CMD="helm3 upgrade --install \"${RELEASE_NAME}\" \"${CHART_DIR}\" \
              --namespace \"${NAMESPACE}\" \
              ${VALUES_ARGS} \
              --set deploy.image.repository=\"${IMAGE_REPO}\" \
              --set deploy.image.tag=\"${IMAGE_TAG}\" \
              --wait \
              --timeout 5m"

            echo "========================================"
            echo "🔍 完整Helm3执行命令如下（可直接复制验证）："
            echo ${FULL_HELM3_CMD}
            echo "========================================"

            echo "🚀 Helm upgrade --install..."
            helm3 upgrade --install "${RELEASE_NAME}" "${CHART_DIR}" \
              --namespace "${NAMESPACE}" \
              ${VALUES_ARGS} \
              --set deploy.image.repository="${IMAGE_REPO}" \
              --set deploy.image.tag="${IMAGE_TAG}" \
              --wait \
              --timeout 5m

            echo "✅ Helm 部署完成，输出状态："
            helm3 status "${RELEASE_NAME}" --namespace "${NAMESPACE}" || true

            # chart 中 deployment 名是：<chartName>-<namespace>
            DEPLOY_NAME="${CHART_NAME}-${NAMESPACE}"
            echo "⏳ 等待 Deployment 就绪：${DEPLOY_NAME}"
            kubectl rollout status deployment/"${DEPLOY_NAME}" -n "${NAMESPACE}" --timeout=300s

            echo "📌 当前资源："
            kubectl get deploy,po,svc,ingress -n "${NAMESPACE}" -l app.kubernetes.io/name="${CHART_NAME}" -o wide || true
          '''
        }
      }
    }
  }
}
