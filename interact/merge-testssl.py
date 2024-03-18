import sys
import os
from bs4 import BeautifulSoup
import re


def merge_html_outputs(html_dir, output_file, urls_file):
    # Read URLs from the text file and filter out HTTP URLs
    with open(urls_file, 'r') as urls:
        url_list = [url.strip() for url in urls.read().splitlines() if not url.startswith("http://")]

    # Create the HTML table with three columns
    num_columns = 3
    num_rows = (len(url_list) + num_columns - 1) // num_columns
    table_html = '<table role="grid" class="table table-striped dataTable">'
    for i in range(num_rows):
        table_html += '<tr>'
        for j in range(num_columns):
            index = i * num_columns + j
            if index < len(url_list):
                table_html += f'<td>{url_list[index]}</td>'
        table_html += '</tr>'
    table_html += '</table>'

    # Create the text indicating the number of URLs present
    num_urls_text = f'Number of URLs scanned : {len(url_list)}'

    # Collect all extracted content
    all_extracted_content = []
    for filename in os.listdir(html_dir):
        html_file = os.path.join(html_dir, filename)
        if os.path.isfile(html_file) and html_file.endswith('.html'):
            with open(html_file, 'r', encoding='utf-8') as f:
                html_content = f.read()
                extracted_content = extract_and_save_content(html_content)
                all_extracted_content.append(extracted_content)

    # Creation of the html merged file
    with open(output_file, 'w', encoding='utf-8') as f:
        # Write the Bootstrap CSS links, table, and URLs text
        f.write('''
        <link crossorigin="anonymous" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css" integrity="sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u" rel="stylesheet"/>
        <link crossorigin="anonymous" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap-theme.min.css" integrity="sha384-rHyoN1iRsVXV4nD0JutlnGaslCJuC7uwjduW9SVrLvRYooPp2bWYgmgJQIXwl/Sp" rel="stylesheet"/>
        <link crossorigin="anonymous" href="https://cdn.datatables.net/1.10.19/css/dataTables.bootstrap.min.css" integrity="sha384-VEpVDzPR2x8NbTDZ8NFW4AWbtT2g/ollEzX/daZdW/YvUBlbgVtsxMftnJ84k0Cn" rel="stylesheet" type="text/css"/>
        ''')
        f.write(f'''
        <div class="container">
          <div class="jumbotron">
            <h1>Scan Report<br/><small>TestSSL 3.2rc3</small>
            </h1>
            <pre style="white-space:pre-wrap; word-wrap:break-word;">testssl.sh -iL input --htmlfile output</pre>
            <p class="lead" style="text-align:center">
                ########################################################### <br>
                  testssl.sh       3.2rc3 from https://testssl.sh/dev/  <br> <br>

                  This program is free software. Distribution and <br>
                          modification under GPLv2 permitted.<br>
                    USAGE w/o ANY WARRANTY. USE IT AT YOUR OWN RISK!<br><br>

                      Please file bugs @ https://testssl.sh/bugs/ <br>
                ###########################################################
            </p>
          </div>
          <h2 class="target">{num_urls_text}</h2>
          {table_html}
          <br><br><br>
        ''')

        # Append extracted content after the table within the container
        for extracted_content in all_extracted_content:
            f.write(extracted_content)

        # Close the container div
        f.write('</div>')

        # Write the Bootstrap JavaScript links and CSS styles
        f.write('''
        <script crossorigin="anonymous" integrity="sha384-fJU6sGmyn07b+uD1nMk7/iSb4yvaowcueiQhfVgQuD98rfva8mcr1eSvjchfpMrH" src="https://code.jquery.com/jquery-3.3.1.js"></script>
        <script crossorigin="anonymous" integrity="sha384-rgWRqC0OFPisxlUvl332tiM/qmaNxnlY46eksSZD84t+s2vZlqGeHrncwIRX7CGp" src="https://cdn.datatables.net/1.10.19/js/jquery.dataTables.min.js"></script>
        <script crossorigin="anonymous" integrity="sha384-7PXRkl4YJnEpP8uU4ev9652TTZSxrqC8uOpcV1ftVEC7LVyLZqqDUAaq+Y+lGgr9" src="https://cdn.datatables.net/1.10.19/js/dataTables.bootstrap.min.js"></script>
        <script crossorigin="anonymous" integrity="sha384-Tc5IQib027qvyjSMfHjOMaLkfuWVxZxUPnCJA7l2mCWNIpG9mGCD8wGNIcPD7Txa" src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js"></script>
        <script>
            $(document).on('click', '.panel-heading span.clickable', function (e) {
            var $this = $(this);
            if (!$this.hasClass('panel-collapsed')) {
                $this.parents('.panel').find('.panel-body').slideUp();
                $this.addClass('panel-collapsed');
                $this.find('i').removeClass('glyphicon-chevron-down').addClass('glyphicon-chevron-right');
            } else {
                $this.parents('.panel').find('.panel-body').slideDown();
                $this.removeClass('panel-collapsed');
                $this.find('i').removeClass('glyphicon-chevron-right').addClass('glyphicon-chevron-down');
            }
            });
            $(document).on('click', '.panel div.clickable', function (e) {
                var $this = $(this);
                if (!$this.hasClass('panel-collapsed')) {
                    $this.parents('.panel').find('.panel-body').slideUp();
                    $this.addClass('panel-collapsed');
                    $this.find('i').removeClass('glyphicon-chevron-down').addClass('glyphicon-chevron-right');
                } else {
                    $this.parents('.panel').find('.panel-body').slideDown();
                    $this.removeClass('panel-collapsed');
                    $this.find('i').removeClass('glyphicon-chevron-right').addClass('glyphicon-chevron-down');
                }
            });
            $(document).ready(function () {
            // Open all panels initially
            $('.panel-body').slideDown();
            $('.panel-heading span.clickable').addClass('panel-collapsed');
            $('.panel-heading span.clickable i').removeClass('glyphicon-chevron-right').addClass('glyphicon-chevron-down');
        });
        </script>
                
        <style>
            .panel-body {
                max-width: 100%;
                padding: 10px;
                overflow: auto;
            }
            
            .panel-body pre {
                word-wrap: break-word;
                white-space: pre-wrap;
                font-family: 'Courier New', Courier, monospace;
            }
        </style>
        ''')


def extract_and_save_content(html_content):
    start_string = "/home/op/recon/testssl.sh/testssl.sh"
    end_string = "Done"
    soup = BeautifulSoup(html_content, 'html.parser')

    pre_tags = soup.find_all('pre')

    if not pre_tags:
        print("No <pre> tags found in the HTML content.")
        return

    url_set = set()
    all_div_content = ""


    for pre_tag in pre_tags:
        pre_content = str(pre_tag)

        # Find the start indices where start_string occurs in the pre_content
        unfiltered_start_indices = [i for i in range(len(pre_content)) if pre_content.startswith(start_string, i)]

        # Filter the start indices where an HTTPS URL follows the start_string
        start_indices = []
        for start_index in unfiltered_start_indices:
            # Find the next occurrence of "https://" after the start index
            https_index = pre_content.find("https://", start_index)
            if https_index != -1:
                # Check if there are any occurrences of "http://" between start_index and https_index
                if "http://" not in pre_content[start_index:https_index]:
                    start_indices.append(start_index)
        end_indices = [i for i in range(
            len(pre_content)) if pre_content.startswith(end_string, i)]
        pre_end_indices = [i for i in range(
            len(pre_content)) if pre_content.startswith('</pre>', i)]

        if not start_indices:
            continue

        i = (len(start_indices) - 1)
        j = (len(end_indices) - 2)
        end_indices.pop()
        start_indices.insert(0, 1)
        while len(start_indices) != (len(end_indices)+2):
            if start_indices[i] < end_indices[j] and start_indices[i-1] < end_indices[j]:
                end_indices.pop(j)
                j -= 1
            else:
                i -= 1
                j -= 1
        start_indices.pop(0)

        end_indices.append(pre_end_indices[0])
        for start_index in start_indices:
            # Find the minimum end index that is greater than the current start index
            end_index = min(filter(lambda x: x > start_index,
                            end_indices + pre_end_indices), default=None)
            if end_index is None:
                break

            extracted_content = pre_content[start_index:end_index +
                                            len(end_string)]

            # Find the URL in the first line using regex
            url_match = re.search(
                r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+', extracted_content)
            if url_match:
                url = url_match.group()
            else:
                url = ""

            if url in url_set:
                # Append to the existing div
                div = soup.find('div', {'id': url})
                if div:
                    div.append(BeautifulSoup(
                        f'<pre>{extracted_content}</pre>', 'html.parser'))
                    div.append(BeautifulSoup(
                        '<span class="done-span">Done</span>', 'html.parser'))
            else:
                # Create a new div
                all_div_content += f'''
                <div class="panel panel-default"> 
                    <div class="panel-heading clickable">
                        <span class="pull-left "><i class="glyphicon glyphicon-chevron-down"></i></span>
                        <h1 class="panel-title">{url}</h1>
                    </div>
                    <div class="panel-body" id="{url}">
                        <pre>{extracted_content}</pre>
                    </div>
                </div>
                '''
                # Add the URL to the set
                url_set.add(url)
    return all_div_content


def main():
    if len(sys.argv) != 4:
        print("Usage: python merge_testssl_html.py input_directory output_file url_file")
        sys.exit(1)

    input_dir = sys.argv[1]
    output_file = sys.argv[2]
    input_file = sys.argv[3]

    merge_html_outputs(input_dir, output_file, input_file)


if __name__ == "__main__":
    main()
