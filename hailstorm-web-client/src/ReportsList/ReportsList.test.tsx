import React, { useState } from 'react';
import { shallow, mount, ReactWrapper } from 'enzyme';
import { ReportsList } from './ReportsList';
import { ReportService } from '../api';
import { act } from '@testing-library/react';

describe('<ReportsList />', () => {
  it('should render without crashing', () => {
    shallow(<ReportsList loadReports={false} setLoadReports={jest.fn()} />);
  });

  it('should reload reports list', (done) => {
    const apiSpy = jest.spyOn(ReportService.prototype, 'list').mockResolvedValue([
      { id: 1, projectId: 1, title: 'a.docx' }
    ]);

    const Wrapper: React.FC = () => {
      const [loadReports, setLoadReports] = useState(true);
      return (
        <ReportsList {...{loadReports, setLoadReports}} />
      );
    };

    let component: ReactWrapper | null = null;
    act(() => {
      component = mount(<Wrapper />);
    });
    expect(apiSpy).toBeCalled();
    setTimeout(() => {
      done();
      component!.update();
      expect(component!.find('a').text()).toMatch(new RegExp('a\.docx'));
    }, 0);
  });
});
