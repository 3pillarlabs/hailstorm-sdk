import React, { useState } from 'react';
import { shallow, mount, ReactWrapper } from 'enzyme';
import { ReportsList } from './ReportsList';
import { ReportService } from "../services/ReportService";
import { act } from '@testing-library/react';
import { Project } from '../domain';

describe('<ReportsList />', () => {
  const project: Project = {id: 1, code: 'a', title: 'A', running: false, autoStop: false};

  const Wrapper: React.FC<{waitingForReport?: boolean}> = ({waitingForReport}) => {
    const [loadReports, setLoadReports] = useState(true);
    return (
      <ReportsList
        {...{loadReports, setLoadReports, project, waitingForReport}}
      />
    );
  };

  it('should render without crashing', () => {
    shallow(<ReportsList loadReports={false} setLoadReports={jest.fn()} {...{project}} />);
  });

  it('should reload reports list', (done) => {
    const apiSpy = jest.spyOn(ReportService.prototype, 'list').mockResolvedValue([
      { id: 1, projectId: 1, title: 'a.docx', uri: 'http://fake.org/reports/123/a.docx' }
    ]);

    let component: ReactWrapper;
    act(() => {
      component = mount(<Wrapper />);
    });

    setTimeout(() => {
      done();
      component.update();
      expect(apiSpy).toBeCalled();
      expect(component.find('a').text()).toMatch(new RegExp('a\.docx'));
    }, 0);
  });

  it('should show a waiting indicator when waiting for a report to be generated', () => {
    const component = mount(
      <ReportsList
        {...{project}}
        loadReports={false}
        setLoadReports={jest.fn()}
        waitingForReport={true}
      />
    );

    component.update();
    expect(component.text()).toMatch(/in progress/i);
  });

  it('should show new label for new reports', (done) => {
    const apiSpy = jest.spyOn(ReportService.prototype, 'list').mockResolvedValue([
      { id: 1, projectId: 1, title: 'a.docx', uri: 'http://fake.org/reports/123/a.docx' }
    ]);

    let component: ReactWrapper;
    act(() => {
      component = mount(<Wrapper />);
    });

    setTimeout(() => {
      done();
      component.update();
      expect(apiSpy).toBeCalled();
      expect(component.find('a').text()).toMatch(new RegExp('a\.docx'));
      component.setProps({waitingForReport: true});
      component.update();
      component.setProps({waitingForReport: false});
      component.update();
      expect(component.find('a').text()).toMatch(/new/);
    }, 0);
  });
});
