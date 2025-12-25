# gitlab-ci 集成代码检测发送邮件用
import sys
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from sonarqube import SonarQubeClient


def sendmail(subject, msg, toaddrs, fromaddr, smtpserver, password):
    mail_msg = MIMEMultipart()
    mail_msg['Subject'] = subject
    mail_msg['From'] = fromaddr
    mail_msg['To'] = ','.join(toaddrs)
    mail_msg.attach(MIMEText(msg, 'html', 'utf-8'))
    try:
        s = smtplib.SMTP_SSL(smtpserver)
        s.connect(smtpserver, 465)  # 连接smtp服务器
        s.login(fromaddr, password)  # 登录邮箱
        s.sendmail(fromaddr, toaddrs, mail_msg.as_string())  # 发送邮件
        s.quit()
        print("send successful！")
    except Exception as e:
        print(e)
        print("Failed to send ")


def getSonarqubeInfo(branch="master", component=None, url=None, username=None, password=None):
    sonar = SonarQubeClient(sonarqube_url=url)
    sonar.auth.authenticate_user(login=username, username=username, password=password)
    component_data = sonar.measures.get_component_with_specified_measures(
        component=component,
        branch=branch,
        fields="metrics,periods",
        metricKeys="""
        code_smells,bugs,coverage,duplicated_lines_density,ncloc,
        security_rating,reliability_rating,vulnerabilities,comment_lines_density,
        ncloc_language_distribution,alert_status,sqale_rating
        """
    )
    result_dict = {}
    for info_dict in component_data["component"]["measures"]:
        result_dict[info_dict["metric"]] = info_dict["value"]
    #print(result_dict)
    return result_dict


def main():
    url = "https://sonarqube.xxxx.top"
    username = "admin"
    password = "admin"
    branch = sys.argv[2]
    project = sys.argv[1]
    project_url = "{}/dashboard?id={}&branch={}".format(url, project, branch)
    user_email = sys.argv[3]
    sonarqube_data = getSonarqubeInfo(branch=branch, component=project, url=url, username=username, password=password)
    html_text = """
<!DOCTYPE html>
<html lang="en">
<head>
    <title></title>
    <meta charset="utf-8">
</head>
<body>
<div class="page" style="margin-left: 30px">
    <h3>{user_mail}, 你好</h3>
    <h3> 本次提交代码检查结果如下</h3>
    <h3> 项目名称：{project} </h3>
    <h3> 分支：{branch} </h3>
    <h4>一、总体情况</h4>
    <ul>
        <li style="font-weight:bold;">
            本次扫描代码行数:&nbsp; <span style="color:blue">{lines} </span>,
            bugs: &nbsp;<span style="color:red">{bugs}</span>,
            Vulnerabilities: &nbsp;<span style="color:red">{vulnerabilities}</span>,
            Code Smells: &nbsp; <span style="color:red">{code_smells}</span>
        </li>
        <li style="font-weight:bold;margin-top: 10px;">
            URL地址：&nbsp;
            <a style="font-weight:bold;"
               href={project_url}>{project_url}
            </a>
        </li>
    </ul>
    <h4>二、信息详情</h4>
    <ul>
        <li style="font-weight:bold;">
           综合等级：&nbsp; {sqale_rating}
        </li>
        <li style="font-weight:bold;">
            各语言扫描行数: &nbsp;{ncloc_language_distribution}
        </li>
        <li style="font-weight:bold;">
            代码重复率: &nbsp;{duplicated_lines_density}
        </li>
        <li style="font-weight:bold;">
            安全等级: &nbsp; {security_rating}
        </li>
        <li style="font-weight:bold;">
            可靠等级: &nbsp; {reliability_rating}
        </li>
        <li style="font-weight:bold;">
            注释行密度: &nbsp;{comment_lines_density}
        </li>
    </ul>
</div>
</body>
</html>
""".format(project_url=project_url,
           user_mail=user_email,
           project=project,
           branch=branch,
           lines=sonarqube_data["ncloc"],
           bugs=sonarqube_data["bugs"],
           vulnerabilities=sonarqube_data["vulnerabilities"],
           code_smells=sonarqube_data["code_smells"],
           ncloc_language_distribution=sonarqube_data["ncloc_language_distribution"],
           duplicated_lines_density=sonarqube_data["duplicated_lines_density"],
           reliability_rating=sonarqube_data["reliability_rating"],
           security_rating=sonarqube_data["security_rating"],
           comment_lines_density=sonarqube_data["comment_lines_density"],
           sqale_rating=sonarqube_data["sqale_rating"]
           )
    fromaddr = "gitlab@xxx.top"
    smtpserver = "smtpdm-ap-southeast-1.aliyun.com"
    toaddrs = [user_email, ]
    subject = "Gitlab代码质量检测"
    password = "password"
    msg = html_text
    #print(msg)
    sendmail(subject, msg, toaddrs, fromaddr, smtpserver, password)


if __name__ == '__main__':
    main()
